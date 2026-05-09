const { Router } = require('express');
const { signToken } = require('../auth/token');
const { UserServiceError } = require('../services/userService');

function createAuthRoutes({ authMiddleware, userService }) {
  const router = Router();

  router.post('/api/auth/register', async (req, res, next) => {
    try {
      const user = await userService.register(req.body || {});
      res.status(201).json({
        user: userService.serializeUser(user),
        token: signToken(user)
      });
    } catch (error) {
      if (error instanceof UserServiceError) {
        return res.status(error.statusCode).json({ message: error.message });
      }
      return next(error);
    }
  });

  router.post('/api/auth/validate', authMiddleware, (req, res) => {
    res.json({ user: userService.serializeUser(req.user) });
  });

  return router;
}

module.exports = {
  createAuthRoutes
};
