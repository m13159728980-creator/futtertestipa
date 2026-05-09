const { Router } = require('express');
const { UserServiceError } = require('../services/userService');

function createUserRoutes({ authMiddleware, userService }) {
  const router = Router();

  router.get('/api/users/check-account', async (req, res, next) => {
    try {
      const available = await userService.isAccountAvailable(req.query.account);
      res.json({ available });
    } catch (error) {
      if (error instanceof UserServiceError) {
        return res.status(error.statusCode).json({ message: error.message });
      }
      return next(error);
    }
  });

  router.patch('/api/users/me/avatar', authMiddleware, async (req, res, next) => {
    try {
      const user = await userService.updateAvatar(req.user.id, req.body.avatarIndex);
      res.json({ user: userService.serializeUser(user) });
    } catch (error) {
      if (error instanceof UserServiceError) {
        return res.status(error.statusCode).json({ message: error.message });
      }
      return next(error);
    }
  });

  router.delete('/api/users/me', authMiddleware, async (req, res, next) => {
    try {
      await userService.softDelete(req.user.id, req.body.account);
      res.status(204).send();
    } catch (error) {
      if (error instanceof UserServiceError) {
        return res.status(error.statusCode).json({ message: error.message });
      }
      return next(error);
    }
  });

  return router;
}

module.exports = {
  createUserRoutes
};
