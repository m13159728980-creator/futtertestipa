const { verifyToken } = require('../auth/token');

function createAuthMiddleware(userService) {
  return async function authMiddleware(req, res, next) {
    const header = req.get('Authorization') || '';
    const match = header.match(/^Bearer\s+(.+)$/i);

    if (!match) {
      return res.status(401).json({ message: '未登录' });
    }

    try {
      const payload = verifyToken(match[1]);
      const user = await userService.validateTokenPayload(payload);

      if (!user) {
        return res.status(401).json({ message: '登录已失效' });
      }

      req.user = user;
      return next();
    } catch (error) {
      return res.status(401).json({ message: '登录已失效' });
    }
  };
}

module.exports = {
  createAuthMiddleware
};
