const { Router } = require('express');
const { GroupServiceError } = require('../services/groupService');

function createContactRoutes({ authMiddleware, groupService, notifier } = {}) {
  const router = Router();

  router.get('/api/contacts', authMiddleware, async (req, res, next) => {
    try {
      const contacts = await groupService.listContacts(req.user.id);
      res.json({ contacts });
    } catch (error) {
      if (error instanceof GroupServiceError) {
        return res.status(error.statusCode).json({ message: error.message });
      }
      return next(error);
    }
  });

  router.post('/api/contacts', authMiddleware, async (req, res, next) => {
    try {
      const before = await groupService.listContacts(req.user.id);
      const contact = await groupService.addContact(req.user.id, req.body?.id ?? req.body?.account);
      const existed = before.some((candidate) => candidate.id === contact.id);
      if (!existed && notifier) {
        notifier([Number(req.user.id), Number(contact.id)], 'contact.updated', {
          userId: Number(req.user.id),
          contactId: Number(contact.id)
        });
      }
      res.status(existed ? 200 : 201).json({ contact });
    } catch (error) {
      if (error instanceof GroupServiceError) {
        return res.status(error.statusCode).json({ message: error.message });
      }
      return next(error);
    }
  });

  return router;
}

module.exports = {
  createContactRoutes
};
