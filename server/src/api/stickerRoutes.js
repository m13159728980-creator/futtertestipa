const path = require('path');
const { Router } = require('express');
const config = require('../config');

const DEFAULT_PACKS = [
  {
    slug: 'official-basic',
    name: 'Official Basic',
    version: 1,
    zipPath: 'official-basic.zip',
    manifest: { stickers: [] },
    official: true
  },
  {
    slug: 'official-reactions',
    name: 'Official Reactions',
    version: 1,
    zipPath: 'official-reactions.zip',
    manifest: { stickers: [] },
    official: true
  },
  {
    slug: 'official-fun',
    name: 'Official Fun',
    version: 1,
    zipPath: 'official-fun.zip',
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

  router.get('/stickers/:pack.zip', (req, res) => {
    const slug = String(req.params.pack || '');
    const pack = DEFAULT_PACKS.find((candidate) => candidate.slug === slug);
    if (!pack) {
      return res.status(404).json({ message: 'Sticker pack not found' });
    }

    const filePath = path.resolve(stickerRoot, pack.zipPath);
    if (!filePath.startsWith(stickerRoot + path.sep)) {
      return res.status(403).json({ message: 'Unsafe sticker path' });
    }
    return res.download(filePath, `${slug}.zip`, (error) => {
      if (error && !res.headersSent) {
        res.status(404).json({ message: 'Sticker pack not found' });
      }
    });
  });

  return router;
}

module.exports = {
  DEFAULT_PACKS,
  createStickerRoutes
};
