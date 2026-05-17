const express = require('express');
const http = require('http');
const cors = require('cors');
const config = require('./src/config');
const healthRoutes = require('./src/api/healthRoutes');
const { createAuthRoutes } = require('./src/api/authRoutes');
const { createContactRoutes } = require('./src/api/contactRoutes');
const { createGroupRoutes } = require('./src/api/groupRoutes');
const { createMessageRoutes } = require('./src/api/messageRoutes');
const { createMediaRoutes } = require('./src/api/mediaRoutes');
const { createStickerRoutes } = require('./src/api/stickerRoutes');
const { createUserRoutes } = require('./src/api/userRoutes');
const { createAuthMiddleware } = require('./src/middleware/auth');
const { createBurnCleanupJob } = require('./src/jobs/burnCleanupJob');
const { createGroupService } = require('./src/services/groupService');
const { createMessageService } = require('./src/services/messageService');
const { createMediaService } = require('./src/services/mediaService');
const { createPushService } = require('./src/services/pushService');
const { createUserService } = require('./src/services/userService');
const { createSocketServer } = require('./src/websocket/socketServer');

function createApp(options = {}) {
  const app = express();
  const userService = options.userService || createUserService(options);
  const pushService = options.pushService || createPushService(options);
  const groupService = createGroupService(options);
  const messageService = options.messageService || createMessageService({ ...options, pushService });
  const mediaService = options.mediaService || createMediaService(options);
  const authMiddleware = createAuthMiddleware(userService);

  app.use(cors());
  app.use(express.json());
  app.use(healthRoutes);
  app.use(createAuthRoutes({ authMiddleware, userService }));
  app.use(createUserRoutes({ authMiddleware, userService }));
  app.use(createContactRoutes({ authMiddleware, groupService, notifier: options.notifier }));
  app.use(createGroupRoutes({ authMiddleware, groupService, notifier: options.notifier }));
  app.use(createMessageRoutes({ authMiddleware, messageService }));
  app.use(createMediaRoutes({ authMiddleware, mediaService, storagePath: options.storagePath }));
  app.use(createStickerRoutes(options));

  return app;
}

if (require.main === module) {
  const userService = createUserService();
  const pushService = createPushService();
  const messageService = createMessageService({ pushService });
  const wsHttpServer = http.createServer();
  const socketServer = createSocketServer({ server: wsHttpServer, messageService, userService });
  const notifier = (targets, type, payload) => socketServer.broadcast(targets, type, payload);
  const app = createApp({ userService, messageService, notifier });
  const burnCleanupJob = createBurnCleanupJob({
    messageService,
    notifier
  });

  app.listen(config.apiPort, () => {
    console.log(`API server listening on port ${config.apiPort}`);
  });
  wsHttpServer.listen(config.wsPort, () => {
    console.log(`WebSocket server listening on port ${config.wsPort}`);
  });
  burnCleanupJob.start();
}

module.exports = { createApp };
