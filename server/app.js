const express = require('express');
const cors = require('cors');
const config = require('./src/config');
const healthRoutes = require('./src/api/healthRoutes');
const { createAuthRoutes } = require('./src/api/authRoutes');
const { createUserRoutes } = require('./src/api/userRoutes');
const { createAuthMiddleware } = require('./src/middleware/auth');
const { createUserService } = require('./src/services/userService');

function createApp(options = {}) {
  const app = express();
  const userService = createUserService(options);
  const authMiddleware = createAuthMiddleware(userService);

  app.use(cors());
  app.use(express.json());
  app.use(healthRoutes);
  app.use(createAuthRoutes({ authMiddleware, userService }));
  app.use(createUserRoutes({ authMiddleware, userService }));

  return app;
}

if (require.main === module) {
  const app = createApp();

  app.listen(config.apiPort, () => {
    console.log(`API server listening on port ${config.apiPort}`);
  });
}

module.exports = { createApp };
