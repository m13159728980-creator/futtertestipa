const crypto = require('crypto');
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');
const { randomUUID } = require('crypto');
const db = require('../../database/db');
const config = require('../config');

const MAX_MEDIA_SIZE_BYTES = 50 * 1024 * 1024;

class MediaServiceError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.name = 'MediaServiceError';
    this.statusCode = statusCode;
  }
}

function mapMediaFile(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.id,
    ownerId: Number(row.ownerId ?? row.owner_id),
    originalName: row.originalName ?? row.original_name,
    mimeType: row.mimeType ?? row.mime_type,
    sizeBytes: Number(row.sizeBytes ?? row.size_bytes),
    storagePath: row.storagePath ?? row.storage_path,
    sha256: row.sha256,
    createdAt: row.createdAt ?? row.created_at ?? null
  };
}

function createPostgresMediaRepository(query = db.query) {
  return {
    async create(file) {
      const { rows } = await query(
        `
          INSERT INTO media_files (id, owner_id, original_name, mime_type, size_bytes, storage_path, sha256)
          VALUES ($1, $2, $3, $4, $5, $6, $7)
          RETURNING id, owner_id, original_name, mime_type, size_bytes, storage_path, sha256, created_at
        `,
        [file.id, file.ownerId, file.originalName, file.mimeType, file.sizeBytes, file.storagePath, file.sha256]
      );
      return mapMediaFile(rows[0]);
    },

    async findById(id) {
      const { rows } = await query(
        `
          SELECT id, owner_id, original_name, mime_type, size_bytes, storage_path, sha256, created_at
          FROM media_files
          WHERE id = $1
          LIMIT 1
        `,
        [id]
      );
      return mapMediaFile(rows[0]);
    }
  };
}

function safeJoin(root, ...parts) {
  const resolvedRoot = path.resolve(root);
  const resolvedPath = path.resolve(resolvedRoot, ...parts);
  if (resolvedPath !== resolvedRoot && !resolvedPath.startsWith(resolvedRoot + path.sep)) {
    throw new MediaServiceError('Unsafe media path', 400);
  }
  return resolvedPath;
}

async function sha256File(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash('sha256');
    const stream = fs.createReadStream(filePath);
    stream.on('error', reject);
    stream.on('data', (chunk) => hash.update(chunk));
    stream.on('end', () => resolve(hash.digest('hex')));
  });
}

function createMediaService(options = {}) {
  const repository = options.mediaRepository || createPostgresMediaRepository(options.query);
  const storageRoot = path.resolve(options.storagePath || config.storagePath);
  const mediaRoot = safeJoin(storageRoot, 'media');

  async function storeUpload(ownerId, file) {
    if (!file || !file.path) {
      throw new MediaServiceError('File is required', 400);
    }
    if (!Number.isInteger(Number(ownerId))) {
      throw new MediaServiceError('Invalid owner', 400);
    }

    const stats = await fsp.stat(file.path);
    const sizeBytes = Number(file.size ?? stats.size);
    if (sizeBytes > MAX_MEDIA_SIZE_BYTES) {
      await fsp.unlink(file.path).catch(() => {});
      throw new MediaServiceError('File exceeds 50 MB limit', 413);
    }

    const id = randomUUID();
    const extension = path.extname(file.originalname || '').slice(0, 32);
    const destination = safeJoin(mediaRoot, `${id}${extension}`);
    await fsp.mkdir(mediaRoot, { recursive: true });
    const sha256 = await sha256File(file.path);
    await fsp.rename(file.path, destination);

    return repository.create({
      id,
      ownerId: Number(ownerId),
      originalName: path.basename(file.originalname || 'upload'),
      mimeType: file.mimetype || 'application/octet-stream',
      sizeBytes,
      storagePath: destination,
      sha256
    });
  }

  async function getFile(id) {
    const file = await repository.findById(id);
    if (!file) {
      throw new MediaServiceError('Media file not found', 404);
    }

    const resolvedPath = path.resolve(file.storagePath);
    if (resolvedPath !== mediaRoot && !resolvedPath.startsWith(mediaRoot + path.sep)) {
      throw new MediaServiceError('Unsafe media path', 403);
    }

    return { ...file, storagePath: resolvedPath };
  }

  return {
    getFile,
    storeUpload
  };
}

module.exports = {
  MAX_MEDIA_SIZE_BYTES,
  MediaServiceError,
  createMediaService,
  createPostgresMediaRepository,
  mapMediaFile
};
