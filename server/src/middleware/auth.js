const { verifyToken } = require('../auth/token');

function createAuthMiddleware(userService) {
  return async function authMiddleware(req, res, next) {
    const header = req.get('Authorization') || '';
    const match = header.match(/^Bearer\s+(.+)$/i);

    if (!match) {
      return res.status(401).json({ message: '\u672a\u767b\u5f55' });
    }

    try {
      const payload = verifyToken(match[1]);
      const user = await userService.validateTokenPayload(payload);

      if (!user) {
        return res.status(401).json({ message: '\u767b\u5f55\u5df2\u5931\u6548' });
      }

      req.user = user;
      return next();
    } catch (error) {
      return res.status(401).json({ message: '\u767b\u5f55\u5df2\u5931\u6548' });
    }
  };
}

module.exports = {
  createAuthMiddleware
};
