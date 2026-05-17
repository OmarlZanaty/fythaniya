'use strict';
require('dotenv').config();

const required = ['DATABASE_URL','JWT_SECRET','JWT_REFRESH_SECRET','ADMIN_JWT_SECRET'];
const missing = required.filter(k => !process.env[k]);
if (missing.length) throw new Error(`Missing env vars: ${missing.join(', ')}`);

module.exports = Object.freeze({
  nodeEnv:     process.env.NODE_ENV || 'development',
  port:        Number(process.env.PORT) || 3000,
  frontendUrl: process.env.FRONTEND_URL || 'http://localhost:3001',
  isProd:      process.env.NODE_ENV === 'production',
  isDev:       process.env.NODE_ENV !== 'production',

  jwt: {
    secret:           process.env.JWT_SECRET,
    // Access token lifetime bumped from 15m → 2h. With our refresh-token rotation interceptor,
    // 15m caused frequent 401s on slow networks and during background polls.
    expiresIn:        process.env.JWT_EXPIRES_IN || '2h',
    refreshSecret:    process.env.JWT_REFRESH_SECRET,
    // 30d refresh window so users stay logged in for a month.
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
    adminSecret:      process.env.ADMIN_JWT_SECRET,
    adminExpiresIn:   process.env.ADMIN_JWT_EXPIRES_IN || '12h',
  },

  firebase: {
    projectId:   process.env.FIREBASE_PROJECT_ID || '',
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL || '',
    privateKey:  (process.env.FIREBASE_PRIVATE_KEY || '').replace(/\\n/g, '\n'),
  },

  twilio: {
    sid:   process.env.TWILIO_ACCOUNT_SID || '',
    token: process.env.TWILIO_AUTH_TOKEN || '',
    phone: process.env.TWILIO_PHONE_NUMBER || '',
  },

  smtp: {
    host: process.env.SMTP_HOST || 'smtp.sendgrid.net',
    port: Number(process.env.SMTP_PORT) || 587,
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    from: process.env.SMTP_FROM || 'noreply@fythaniya.com',
  },

  sla: {
    standard: Number(process.env.SLA_STANDARD_MINUTES) || 15,
    critical: Number(process.env.SLA_CRITICAL_MINUTES) || 5,
    l1:       Number(process.env.SLA_L1_MINUTES) || 10,
    l2:       Number(process.env.SLA_L2_MINUTES) || 20,
    l3:       Number(process.env.SLA_L3_MINUTES) || 40,
  },

  rateLimit: {
    windowMs: Number(process.env.RATE_LIMIT_WINDOW_MS) || 900000,
    max:      Number(process.env.RATE_LIMIT_MAX) || 100,
  },
});
