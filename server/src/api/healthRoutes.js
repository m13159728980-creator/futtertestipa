const { Router } = require('express');

const router = Router();

router.get('/api/health', (req, res) => {
  res.json({ ok: true });
});

module.exports = router;
