const { Router } = require('express');
const { GroupServiceError } = require('../services/groupService');

function createGroupRoutes({ authMiddleware, groupService, notifier } = {}) {
  const router = Router();

  function handleError(error, res, next) {
    if (error instanceof GroupServiceError) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }

  router.get('/api/groups', authMiddleware, async (req, res, next) => {
    try {
      const groups = await groupService.listGroups(req.user.id);
      res.json({ groups });
    } catch (error) {
      return handleError(error, res, next);
    }
  });

  router.post('/api/groups', authMiddleware, async (req, res, next) => {
    try {
      const group = await groupService.createGroup(req.user.id, req.body || {});
      notifyGroup(notifier, group);
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
      notifyGroup(notifier, group);
      res.json({ group });
    } catch (error) {
      return handleError(error, res, next);
    }
  });

  router.post('/api/groups/:id/members', authMiddleware, async (req, res, next) => {
    try {
      const group = await groupService.addMembers(req.user.id, req.params.id, req.body?.memberIds);
      notifyGroup(notifier, group);
      res.status(201).json({ group });
    } catch (error) {
      return handleError(error, res, next);
    }
  });

  router.delete('/api/groups/:id/members/:userId', authMiddleware, async (req, res, next) => {
    try {
      await groupService.removeMember(req.user.id, req.params.id, req.params.userId);
      const group = await groupService.getGroup(req.user.id, req.params.id);
      notifyGroup(notifier, group);
      res.status(204).send();
    } catch (error) {
      return handleError(error, res, next);
    }
  });

  router.patch('/api/groups/:id/members/:userId/role', authMiddleware, async (req, res, next) => {
    try {
      const group = await groupService.setMemberRole(req.user.id, req.params.id, req.params.userId, req.body?.role);
      notifyGroup(notifier, group);
      res.json({ group });
    } catch (error) {
      return handleError(error, res, next);
    }
  });

  return router;
}

function notifyGroup(notifier, group) {
  if (!notifier || !group) {
    return;
  }
  const targets = (group.members || []).map((member) => Number(member.userId));
  notifier(targets, 'group.updated', { group });
}

module.exports = {
  createGroupRoutes
};
