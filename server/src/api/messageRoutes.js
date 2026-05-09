const { Router } = require('express');
const { MessageServiceError } = require('../services/messageService');

function createMessageRoutes({ authMiddleware, messageService }) {
  const router = Router();

  function handleError(error, res, next) {
    if (error instanceof MessageServiceError) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }

  router.post('/api/messages/sync', authMiddleware, async (req, res, next) => {
    try {
      const messages = await messageService.syncMessages(req.user.id);
      return res.json({ messages });
    } catch (error) {
      return handleError(error, res, next);
    }
  });

  return router;
}

module.exports = {
  createMessageRoutes
};
