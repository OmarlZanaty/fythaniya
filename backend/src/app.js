'use strict';
const config = require('./config/env');
const express  = require('express');
const http     = require('http');
const { Server } = require('socket.io');
const helmet     = require('helmet');
const cors       = require('cors');
const compression = require('compression');

const { logger, jwtUtils } = require('./utils/all');
const { requestLogger, errorHandler, apiLimiter, adminLimiter } = require('./middleware/index');

const authRouter    = require('./modules/auth/auth.routes');
const servicesRouter= require('./modules/services/services.routes');
const b2bRouter     = require('./modules/b2b/b2b.routes');
const adminRouter   = require('./modules/admin/admin.routes');
const userRouter    = require('./modules/user_routes');
const { startJobs } = require('./jobs/jobs');

const app    = express();
app.set('trust proxy', 1);
const server = http.createServer(app);

// Allowed origins for CORS. Default '*' so native mobile apps work (they don't send Origin),
// but in production set CORS_ORIGINS to a comma-separated list of trusted web origins.
const corsOriginsEnv = process.env.CORS_ORIGINS;
const corsOrigin = corsOriginsEnv ? corsOriginsEnv.split(',').map(s => s.trim()) : '*';
if (corsOrigin === '*') logger.warn('CORS_ORIGINS not set — allowing all origins. Set CORS_ORIGINS=https://your-domain.com for production.');

// ── Socket.IO ─────────────────────────────────────────────────────────────────
const io = new Server(server, {
  cors: { origin: corsOrigin, methods: ['GET','POST'] },
  transports: ['websocket','polling'],
});

app.set('io', io);

io.use((socket, next) => {
  const token = socket.handshake.auth?.token;
  if (!token) return next(new Error('No token'));
  try {
    // Try admin token first, then user token
    try {
      const decoded = jwtUtils.verifyAdmin(token);
      socket.admin = decoded;
      return next();
    } catch {
      const decoded = jwtUtils.verifyUser(token);
      socket.user = decoded;
      return next();
    }
  } catch { next(new Error('Invalid token')); }
});

io.on('connection', (socket) => {
  if (socket.admin) {
    socket.join('admin_room');
    logger.info(`[SOCKET] Admin connected: ${socket.admin.email}`);
    socket.on('disconnect', () => logger.info(`[SOCKET] Admin disconnected: ${socket.admin.email}`));
  } else if (socket.user) {
    socket.join(`user_${socket.user.id}`);
    logger.info(`[SOCKET] User connected: ${socket.user.id}`);
    socket.on('disconnect', () => logger.info(`[SOCKET] User disconnected: ${socket.user.id}`));
  }
});

// ── Core Middleware ───────────────────────────────────────────────────────────
app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false }));
app.use(cors({ origin: corsOrigin, methods: ['GET','POST','PUT','PATCH','DELETE','OPTIONS'], allowedHeaders: ['Content-Type','Authorization'] }));
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(requestLogger);

// ── Health Check ──────────────────────────────────────────────────────────────
app.get('/api/v1/health', (req, res) => res.json({
  success: true, status: 'ok', env: config.nodeEnv,
  timestamp: new Date().toISOString(), uptime: Math.floor(process.uptime()),
}));

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api/v1/auth',     apiLimiter, authRouter);
app.use('/api/v1/services', apiLimiter, servicesRouter);
app.use('/api/v1/b2b',      apiLimiter, b2bRouter);
app.use('/api/v1/admin',    adminLimiter, adminRouter);
app.use('/api/v1/user',     apiLimiter, userRouter);

// ── 404 ───────────────────────────────────────────────────────────────────────
app.use('*', (req, res) => res.status(404).json({ success: false, message: `Not found: ${req.method} ${req.originalUrl}` }));

// ── Error Handler ─────────────────────────────────────────────────────────────
app.use(errorHandler);

// ── Start Server ──────────────────────────────────────────────────────────────
server.listen(config.port, () => {
  logger.info(`🚀 فى ثانية v2.0 running on port ${config.port} [${config.nodeEnv}]`);
  logger.info(`📡 Health: http://localhost:${config.port}/api/v1/health`);
  startJobs(io);
});

// ── Graceful Shutdown ─────────────────────────────────────────────────────────
const shutdown = async () => {
  logger.info('Shutting down...');
  await require('./config/database').$disconnect();
  server.close(() => { logger.info('Server closed'); process.exit(0); });
};
process.on('SIGTERM', shutdown);
process.on('SIGINT',  shutdown);
process.on('unhandledRejection', (r) => logger.error('Unhandled rejection:', r));
process.on('uncaughtException',  (e) => { logger.error('Uncaught exception:', e); process.exit(1); });

module.exports = { app, server, io };
