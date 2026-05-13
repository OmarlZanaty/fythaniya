'use strict';
const rateLimit = require('express-rate-limit');
const morgan    = require('morgan');
const { validationResult } = require('express-validator');
const { jwtUtils, apiResponse, logger } = require('../utils/all');
const prisma  = require('../config/database');
const config  = require('../config/env');

// ── Auth ─────────────────────────────────────────────────────────────────────
const authenticateUser = async (req, res, next) => {
  try {
    const h = req.headers.authorization;
    if (!h?.startsWith('Bearer ')) return apiResponse.error(res, 'No token', 401);
    const decoded = jwtUtils.verifyUser(h.split(' ')[1]);
    const user = await prisma.user.findUnique({ where: { id: decoded.id } });
    if (!user) return apiResponse.error(res, 'User not found', 401);
    if (user.status === 'SUSPENDED') return apiResponse.error(res, 'Account suspended', 403);
    if (user.status === 'BANNED')    return apiResponse.error(res, 'Account banned', 403);
    req.user = { id: user.id, phone: user.phone, type: user.type, status: user.status };
    next();
  } catch (e) {
    if (e.name === 'TokenExpiredError') return apiResponse.error(res, 'Token expired', 401);
    return apiResponse.error(res, 'Invalid token', 401);
  }
};

const authenticateAdmin = async (req, res, next) => {
  try {
    const h = req.headers.authorization;
    if (!h?.startsWith('Bearer ')) return apiResponse.error(res, 'No token', 401);
    const decoded = jwtUtils.verifyAdmin(h.split(' ')[1]);
    const admin = await prisma.admin.findUnique({ where: { id: decoded.id } });
    if (!admin || !admin.isActive) return apiResponse.error(res, 'Unauthorized', 401);
    req.admin = { id: admin.id, email: admin.email, role: admin.role, fullName: admin.fullName };
    next();
  } catch (e) {
    if (e.name === 'TokenExpiredError') return apiResponse.error(res, 'Session expired', 401);
    return apiResponse.error(res, 'Invalid token', 401);
  }
};

// ── RBAC ─────────────────────────────────────────────────────────────────────
const requireRole = (...roles) => (req, res, next) => {
  if (!req.admin) return apiResponse.error(res, 'Unauthorized', 401);
  if (req.admin.role === 'SUPER_ADMIN') return next();
  if (roles.includes(req.admin.role)) return next();
  return apiResponse.error(res, 'Insufficient permissions', 403);
};

// ── Validate ─────────────────────────────────────────────────────────────────
const validate = (req, res, next) => {
  const errs = validationResult(req);
  if (!errs.isEmpty()) return apiResponse.error(res, errs.array()[0].msg, 400, errs.array());
  next();
};

// ── Rate Limiters ─────────────────────────────────────────────────────────────
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, max: 20,
  message: { success: false, message: 'Too many attempts, try again in 15 minutes.' },
  standardHeaders: true, legacyHeaders: false,
});

const apiLimiter = rateLimit({
  windowMs: config.rateLimit.windowMs, max: config.rateLimit.max,
  message: { success: false, message: 'Rate limit exceeded.' },
  standardHeaders: true, legacyHeaders: false,
});

const adminLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, max: 500,
  message: { success: false, message: 'Rate limit exceeded.' },
  standardHeaders: true, legacyHeaders: false,
});

// ── Request Logger ─────────────────────────────────────────────────────────────
const requestLogger = morgan('combined', {
  stream: { write: (msg) => logger.info(msg.trim()) },
  skip: (req) => req.path === '/api/v1/health',
});

// ── Error Handler ─────────────────────────────────────────────────────────────
const errorHandler = (err, req, res, next) => {
  logger.error({ message: err.message, stack: err.stack, path: req.path });
  if (err.code === 'P2002') return apiResponse.error(res, 'Already exists', 409);
  if (err.code === 'P2025') return apiResponse.error(res, 'Not found', 404);
  if (err.code === 'P2003') return apiResponse.error(res, 'Invalid reference', 400);
  if (err.name === 'JsonWebTokenError') return apiResponse.error(res, 'Invalid token', 401);
  if (err.name === 'TokenExpiredError') return apiResponse.error(res, 'Token expired', 401);
  if (config.isDev) return res.status(500).json({ success: false, message: err.message, stack: err.stack });
  return apiResponse.error(res, 'Internal server error', 500);
};

module.exports = {
  authenticateUser, authenticateAdmin, requireRole, validate,
  authLimiter, apiLimiter, adminLimiter, requestLogger, errorHandler,
};
