const crypto = require('crypto');

const API_KEY = process.env.API_KEY || 'delisure-demo-key-2026';

const ADMIN_USERNAME = process.env.ADMIN_USERNAME || 'admin';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'delisure@admin2026';
const ADMIN_TOKEN_SECRET = process.env.ADMIN_TOKEN_SECRET || 'delisure-admin-secret-key-2026';

const activeAdminTokens = new Set();

function generateAdminToken(username) {
  const payload = `${username}:${Date.now()}:${crypto.randomBytes(16).toString('hex')}`;
  const signature = crypto.createHmac('sha256', ADMIN_TOKEN_SECRET).update(payload).digest('hex');
  const token = Buffer.from(`${payload}:${signature}`).toString('base64');
  activeAdminTokens.add(token);
  return token;
}

function verifyAdminToken(token) {
  if (!token || !activeAdminTokens.has(token)) return false;
  try {
    const decoded = Buffer.from(token, 'base64').toString('utf8');
    const parts = decoded.split(':');
    if (parts.length !== 4) return false;
    const [username, ts, nonce, signature] = parts;
    const expected = crypto.createHmac('sha256', ADMIN_TOKEN_SECRET)
      .update(`${username}:${ts}:${nonce}`).digest('hex');
    return signature === expected && username === ADMIN_USERNAME;
  } catch {
    return false;
  }
}

function revokeAdminToken(token) {
  activeAdminTokens.delete(token);
}

function verifyAdminCredentials(username, password) {
  return username === ADMIN_USERNAME && password === ADMIN_PASSWORD;
}

function authMiddleware(req, res, next) {
  if (req.path === '/api/health') return next();

  const apiKey = req.headers['x-api-key'] || req.query.apiKey;
  if (!apiKey || apiKey !== API_KEY) {
    return res.status(401).json({ error: 'Unauthorized — provide x-api-key header' });
  }
  next();
}

function requireAdmin(req, res, next) {
  const token = req.headers['x-admin-token'] || req.query.adminToken;
  if (!token || !verifyAdminToken(token)) {
    return res.status(403).json({ error: 'Forbidden — admin access required. Log in via /api/admin/login' });
  }
  req.adminToken = token;
  next();
}

module.exports = {
  authMiddleware,
  requireAdmin,
  generateAdminToken,
  verifyAdminToken,
  revokeAdminToken,
  verifyAdminCredentials,
  API_KEY,
  ADMIN_USERNAME,
};
