const express = require('express');
const cors = require('cors');
const config = require('./src/config');
const healthRoutes = require('./src/api/healthRoutes');

function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json());
  app.use(healthRoutes);

  return app;
}

if (require.main === module) {
  const app = createApp();

  app.listen(config.apiPort, () => {
    console.log(`API server listening on port ${config.apiPort}`);
  });
}

module.exports = { createApp };
