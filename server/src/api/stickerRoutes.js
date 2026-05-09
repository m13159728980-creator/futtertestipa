const path = require('path');
const { Router } = require('express');
const config = require('../config');

const DEFAULT_PACKS = [
  {
    slug: 'pack1',
    name: 'Gram Basics',
    version: 1,
    zipPath: 'pack1.zip',
    manifest: { stickers: [] },
    official: true
  },
  {
    slug: 'pack2',
    name: 'Secure Mood',
    version: 1,
    zipPath: 'pack2.zip',
    manifest: { stickers: [] },
    official: true
  },
  {
    slug: 'pack3',
    name: 'Daily Signals',
    version: 1,
    zipPath: 'pack3.zip',
    manifest: { stickers: [] },
    official: true
  }
];

function normalizePack(row) {
  return {
    id: row.id ?? row.slug,
    slug: row.slug,
    name: row.name,
    version: Number(row.version || 1),
    manifest: row.manifest || {},
    downloadUrl: `/stickers/${row.slug}.zip`,
    official: row.official ?? true
  };
}

function createStickerRoutes(options = {}) {
  const router = Router();
  const storagePath = path.resolve(options.storagePath || config.storagePath);
  const stickerRoot = path.resolve(storagePath, 'stickers');
  const repository = options.stickerRepository;

  router.get('/api/stickers/packs', async (req, res, next) => {
    try {
      const packs = repository && repository.listActivePacks
        ? await repository.listActivePacks()
        : DEFAULT_PACKS;
      res.json({ packs: packs.map(normalizePack) });
    } catch (error) {
      next(error);
    }
  });

  async function findPackBySlug(slug) {
    if (repository && repository.findActivePackBySlug) {
      return repository.findActivePackBySlug(slug);
    }
    return DEFAULT_PACKS.find((candidate) => candidate.slug === slug) || null;
  }

  function safeStickerPath(pack) {
    const zipPath = pack.zipPath ?? pack.zip_path;
    const filePath = path.resolve(stickerRoot, zipPath || '');
    if (filePath !== stickerRoot && !filePath.startsWith(stickerRoot + path.sep)) {
      return null;
    }
    return filePath;
  }

  router.get('/stickers/:pack.zip', async (req, res, next) => {
    const slug = String(req.params.pack || '');
    try {
      const pack = await findPackBySlug(slug);
      if (!pack) {
        return res.status(404).json({ message: 'Sticker pack not found' });
      }

      const filePath = safeStickerPath(pack);
      if (!filePath) {
        return res.status(403).json({ message: 'Unsafe sticker path' });
      }

      return res.download(filePath, `${slug}.zip`, (error) => {
        if (error && !res.headersSent) {
          res.status(404).json({ message: 'Sticker pack not found' });
        }
      });
    } catch (error) {
      return next(error);
    }
  });

  return router;
}

module.exports = {
  DEFAULT_PACKS,
  createStickerRoutes
};
