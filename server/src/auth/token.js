const jwt = require('jsonwebtoken');
const config = require('../config');

function signToken(user) {
  return jwt.sign(
    {
      userId: Number(user.id),
      account: user.account,
      tokenVersion: Number(user.tokenVersion || 0)
    },
    config.jwtSecret
  );
}

function verifyToken(token) {
  return jwt.verify(token, config.jwtSecret);
}

module.exports = {
  signToken,
  verifyToken
};
