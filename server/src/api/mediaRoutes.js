const fs = require('fs');
const path = require('path');
const { Router } = require('express');
const multer = require('multer');
const config = require('../config');
const { MAX_MEDIA_SIZE_BYTES, MediaServiceError } = require('../services/mediaService');

function createMediaRoutes({ authMiddleware, mediaService, storagePath = config.storagePath }) {
  const router = Router();
  const tmpRoot = path.resolve(storagePath, 'tmp', 'media');
  fs.mkdirSync(tmpRoot, { recursive: true });
  const upload = multer({
    dest: tmpRoot,
    limits: { fileSize: MAX_MEDIA_SIZE_BYTES }
  });

  function handleError(error, res, next) {
    if (error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({ message: 'File exceeds 50 MB limit' });
    }
    if (error instanceof MediaServiceError) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }

  router.post('/api/media/upload', authMiddleware, (req, res, next) => {
    upload.single('file')(req, res, async (error) => {
      if (error) {
        return handleError(error, res, next);
      }

      try {
        const file = await mediaService.storeUpload(req.user.id, req.file);
        return res.status(201).json({ file });
      } catch (storeError) {
        return handleError(storeError, res, next);
      }
    });
  });

  router.get('/api/media/:id', async (req, res, next) => {
    try {
      const file = await mediaService.getFile(req.params.id);
      res.type(file.mimeType);
      res.set('Content-Length', String(file.sizeBytes));
      return res.sendFile(file.storagePath);
    } catch (error) {
      return handleError(error, res, next);
    }
  });

  return router;
}

module.exports = {
  createMediaRoutes
};
