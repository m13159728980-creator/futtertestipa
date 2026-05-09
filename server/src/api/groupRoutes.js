const { Router } = require('express');
const { GroupServiceError } = require('../services/groupService');

function createGroupRoutes({ authMiddleware, groupService }) {
  const router = Router();

  function handleError(error, res, next) {
    if (error instanceof GroupServiceError) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }

  router.post('/api/groups', authMiddleware, async (req, res, next) => {
    try {
      const group = await groupService.createGroup(req.user.id, req.body || {});
      res.status(201).json({ group });
    } catch (error) {
      return handleError(error, res, next);
    }
  });

  router.get('/api/groups/:id', authMiddleware, async (req, res, next) => {
    try {
      const group = await groupService.getGroup(req.user.id, req.params.id);
      res.json({ group });
    } catch (error) {
      return handleError(error, res, next);
    }
  });

  router.patch('/api/groups/:id', authMiddleware, async (req, res, next) => {
    try {
      const group = await groupService.renameGroup(req.user.id, req.params.id, req.body?.name);
      res.json({ group });
    } catch (error) {
      return handleError(error, res, next);
    }
  });

  router.post('/api/groups/:id/members', authMiddleware, async (req, res, next) => {
    try {
      const group = await groupService.addMembers(req.user.id, req.params.id, req.body?.memberIds);
      res.status(201).json({ group });
    } catch (error) {
      return handleError(error, res, next);
    }
  });

  router.delete('/api/groups/:id/members/:userId', authMiddleware, async (req, res, next) => {
    try {
      await groupService.removeMember(req.user.id, req.params.id, req.params.userId);
      res.status(204).send();
    } catch (error) {
      return handleError(error, res, next);
    }
  });

  router.patch('/api/groups/:id/members/:userId/role', authMiddleware, async (req, res, next) => {
    try {
      const group = await groupService.setMemberRole(req.user.id, req.params.id, req.params.userId, req.body?.role);
      res.json({ group });
    } catch (error) {
      return handleError(error, res, next);
    }
  });

  return router;
}

module.exports = {
  createGroupRoutes
};
