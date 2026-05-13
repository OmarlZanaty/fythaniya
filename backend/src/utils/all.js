'use strict';
// ═══════════════════════════════════════════════════════════
//  ALL UTILITIES IN ONE FILE
// ═══════════════════════════════════════════════════════════

// ── Logger ───────────────────────────────────────────────────────────────────
const { createLogger, format, transports } = require('winston');
require('winston-daily-rotate-file');
const config = require('../config/env');

const logger = createLogger({
  level: config.isProd ? 'info' : 'debug',
  format: format.combine(
    format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    format.errors({ stack: true }),
    format.json()
  ),
  transports: [
    new transports.DailyRotateFile({
      filename: 'logs/error-%DATE%.log', datePattern: 'YYYY-MM-DD',
      level: 'error', maxFiles: '14d', zippedArchive: true,
    }),
    new transports.DailyRotateFile({
      filename: 'logs/combined-%DATE%.log', datePattern: 'YYYY-MM-DD',
      maxFiles: '14d', zippedArchive: true,
    }),
  ],
});
if (config.isDev) logger.add(new transports.Console({ format: format.combine(format.colorize(), format.simple()) }));
module.exports.logger = logger;

// ── JWT ──────────────────────────────────────────────────────────────────────
const jwt = require('jsonwebtoken');
module.exports.jwtUtils = {
  signUser:         (p) => jwt.sign(p, config.jwt.secret,        { expiresIn: config.jwt.expiresIn }),
  signRefresh:      (p) => jwt.sign(p, config.jwt.refreshSecret, { expiresIn: config.jwt.refreshExpiresIn }),
  signAdmin:        (p) => jwt.sign(p, config.jwt.adminSecret,   { expiresIn: config.jwt.adminExpiresIn }),
  verifyUser:       (t) => jwt.verify(t, config.jwt.secret),
  verifyRefresh:    (t) => jwt.verify(t, config.jwt.refreshSecret),
  verifyAdmin:      (t) => jwt.verify(t, config.jwt.adminSecret),
};

// ── Bcrypt ───────────────────────────────────────────────────────────────────
const bcrypt = require('bcryptjs');
module.exports.hashPassword    = (p) => bcrypt.hash(p, 12);
module.exports.comparePassword = (p, h) => bcrypt.compare(p, h);

// ── API Response ─────────────────────────────────────────────────────────────
module.exports.apiResponse = {
  success(res, data = null, message = 'Success', code = 200) {
    return res.status(code).json({ success: true, message, data });
  },
  error(res, message = 'Error', code = 400, errors = null) {
    const b = { success: false, message };
    if (errors) b.errors = errors;
    return res.status(code).json(b);
  },
  paginated(res, data, total, page, limit) {
    page = Number(page); limit = Number(limit);
    return res.json({
      success: true, data,
      pagination: {
        total, page, limit,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page * limit < total,
        hasPrevPage: page > 1,
      },
    });
  },
};

// ── Pagination ───────────────────────────────────────────────────────────────
module.exports.paginate = (q) => {
  const page  = Math.max(1, parseInt(q.page) || 1);
  const limit = Math.min(100, parseInt(q.limit) || 20);
  return { page, limit, skip: (page - 1) * limit };
};

// ── OTP ──────────────────────────────────────────────────────────────────────
module.exports.generateOTP = () =>
  Math.floor(100000 + Math.random() * 900000).toString();

// ── Firebase Push ─────────────────────────────────────────────────────────────
const admin = require('firebase-admin');
let fbReady = false;
if (config.firebase.projectId && !config.firebase.projectId.startsWith('YOUR')) {
  try {
    if (!admin.apps.length) {
      admin.initializeApp({ credential: admin.credential.cert(config.firebase) });
    }
    fbReady = true;
    logger.info('Firebase ready');
  } catch (e) { logger.warn('Firebase init failed:', e.message); }
}

const sendPush = async (token, title, body, data = {}) => {
  if (!fbReady || !token) return null;
  try {
    const d = {};
    for (const [k, v] of Object.entries(data)) d[k] = String(v);
    return await admin.messaging().send({
      token, notification: { title, body }, data: d,
      android: { priority: 'high', notification: { sound: 'default', channelId: 'fythaniya_high' } },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });
  } catch (e) { logger.error('[PUSH]', e.message); return null; }
};

const sendMulticastPush = async (tokens, title, body, data = {}) => {
  if (!fbReady || !tokens.length) return null;
  const valid = tokens.filter(Boolean);
  if (!valid.length) return null;
  try {
    const d = {};
    for (const [k, v] of Object.entries(data)) d[k] = String(v);
    return await admin.messaging().sendEachForMulticast({
      tokens: valid, notification: { title, body }, data: d,
      android: { priority: 'high' },
    });
  } catch (e) { logger.error('[MULTICAST]', e.message); return null; }
};

module.exports.sendPush = sendPush;
module.exports.sendMulticastPush = sendMulticastPush;

// ── Notification Helpers ──────────────────────────────────────────────────────
const prisma = require('../config/database');

module.exports.notifyUser = async (userId, title, body, priority = 'HIGH', data = null) => {
  try {
    const notif = await prisma.userNotification.create({
      data: { userId, title, body, priority, channel: 'IN_APP', data },
    });
    const user = await prisma.user.findUnique({ where: { id: userId }, select: { deviceToken: true } });
    if (user?.deviceToken) await sendPush(user.deviceToken, title, body, data || {});
    return notif;
  } catch (e) { logger.error('[NOTIFY_USER]', e.message); }
};

module.exports.notifyAdmins = async (title, body, priority = 'CRITICAL', requestId = null, roles = null, data = null) => {
  try {
    const where = { isActive: true };
    if (roles) where.role = { in: roles };
    const admins = await prisma.admin.findMany({ where });
    await Promise.all(admins.map(a =>
      prisma.adminNotification.create({
        data: { adminId: a.id, title, body, priority, requestId, data },
      })
    ));
    const tokens = admins.map(a => a.deviceToken).filter(Boolean);
    if (tokens.length) await sendMulticastPush(tokens, title, body, data || {});
    return admins.length;
  } catch (e) { logger.error('[NOTIFY_ADMINS]', e.message); }
};

// ── Socket emit helper ────────────────────────────────────────────────────────
module.exports.emitToAdmins = (io, event, data) => {
  if (io) io.to('admin_room').emit(event, data);
};

module.exports.emitToUser = (io, userId, event, data) => {
  if (io) io.to(`user_${userId}`).emit(event, data);
};
