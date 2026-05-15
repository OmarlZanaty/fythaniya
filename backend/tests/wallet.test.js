'use strict';

// Mock prisma BEFORE requiring routes — keeps tests isolated from the DB.
const mockPrisma = {
  user: { findUnique: jest.fn(), update: jest.fn(), updateMany: jest.fn() },
  transaction: { create: jest.fn() },
  $transaction: jest.fn(),
};
const mockNotify = jest.fn();

jest.mock('../src/config/database', () => mockPrisma);
jest.mock('../src/utils/all', () => {
  const actual = jest.requireActual('../src/utils/all');
  return { ...actual, notifyUser: mockNotify, notifyAdmins: jest.fn(), logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn() } };
});
jest.mock('../src/middleware/index', () => {
  const { validationResult } = require('express-validator');
  return {
    // Stub auth — inject a fixed user; real auth needs the DB.
    authenticateUser: (req, res, next) => { req.user = { id: 'sender-id' }; next(); },
    authenticateAdmin: (req, res, next) => { req.admin = { id: 'admin-id', role: 'SUPER_ADMIN' }; next(); },
    authLimiter: (req, res, next) => next(),
    apiLimiter: (req, res, next) => next(),
    adminLimiter: (req, res, next) => next(),
    // Keep REAL validate so body() rules actually run.
    validate: (req, res, next) => {
      const errs = validationResult(req);
      if (!errs.isEmpty()) return res.status(400).json({ success: false, message: errs.array()[0].msg });
      next();
    },
    requestLogger: (req, res, next) => next(),
    requireRole: () => (req, res, next) => next(),
    errorHandler: (err, req, res, next) => res.status(500).json({ success: false, message: err.message }),
  };
});

const express = require('express');
const request = require('supertest');
const userRouter = require('../src/modules/user_routes');

function makeApp() {
  const app = express();
  app.use(express.json());
  app.use('/api/v1/user', userRouter);
  return app;
}

beforeEach(() => {
  jest.clearAllMocks();
  // Default $transaction implementation runs the callback with our mockPrisma.
  mockPrisma.$transaction.mockImplementation(async (fn) => fn(mockPrisma));
});

describe('POST /user/wallet/topup', () => {
  test('rejects amount below minimum', async () => {
    const res = await request(makeApp()).post('/api/v1/user/wallet/topup').send({ amount: 5 });
    expect(res.status).toBe(400);
  });

  test('rejects amount above maximum', async () => {
    const res = await request(makeApp()).post('/api/v1/user/wallet/topup').send({ amount: 999999 });
    expect(res.status).toBe(400);
  });

  test('credits wallet and creates transaction on success', async () => {
    mockPrisma.user.update.mockResolvedValue({ walletBalance: 150 });
    mockPrisma.transaction.create.mockResolvedValue({ id: 'txn-1' });

    const res = await request(makeApp()).post('/api/v1/user/wallet/topup').send({ amount: 100 });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(mockPrisma.user.update).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 'sender-id' },
      data: { walletBalance: { increment: 100 } },
    }));
    expect(mockPrisma.transaction.create).toHaveBeenCalled();
    expect(mockNotify).toHaveBeenCalled();
  });
});

describe('POST /user/wallet/transfer', () => {
  test('rejects self-transfer', async () => {
    mockPrisma.user.findUnique.mockResolvedValueOnce({ phone: '01067189023' });

    const res = await request(makeApp())
      .post('/api/v1/user/wallet/transfer')
      .send({ toPhone: '01067189023', amount: 50 });

    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/نفسك/);
  });

  test('rejects when recipient not found', async () => {
    mockPrisma.user.findUnique
      .mockResolvedValueOnce({ phone: '01067189023' }) // sender phone lookup
      .mockResolvedValueOnce(null); // recipient lookup

    const res = await request(makeApp())
      .post('/api/v1/user/wallet/transfer')
      .send({ toPhone: '01099999999', amount: 50 });

    expect(res.status).toBe(404);
  });

  test('rejects when recipient is not ACTIVE', async () => {
    mockPrisma.user.findUnique
      .mockResolvedValueOnce({ phone: '01067189023' })
      .mockResolvedValueOnce({ id: 'r-id', phone: '01099999999', fullName: 'X', status: 'SUSPENDED' });

    const res = await request(makeApp())
      .post('/api/v1/user/wallet/transfer')
      .send({ toPhone: '01099999999', amount: 50 });

    expect(res.status).toBe(400);
  });

  test('rejects when balance insufficient (atomic guard)', async () => {
    mockPrisma.user.findUnique
      .mockResolvedValueOnce({ phone: '01067189023' })
      .mockResolvedValueOnce({ id: 'r-id', phone: '01099999999', fullName: 'X', status: 'ACTIVE' });
    // The atomic updateMany returns count: 0 → balance was insufficient.
    mockPrisma.user.updateMany.mockResolvedValue({ count: 0 });

    const res = await request(makeApp())
      .post('/api/v1/user/wallet/transfer')
      .send({ toPhone: '01099999999', amount: 50 });

    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/الرصيد/);
  });

  test('completes transfer atomically on success', async () => {
    mockPrisma.user.findUnique
      .mockResolvedValueOnce({ phone: '01067189023' }) // sender phone
      .mockResolvedValueOnce({ id: 'r-id', phone: '01099999999', fullName: 'Recipient', status: 'ACTIVE' }) // recipient lookup
      .mockResolvedValueOnce({ walletBalance: 50, fullName: 'Sender' }); // final balance read
    mockPrisma.user.updateMany.mockResolvedValue({ count: 1 });
    mockPrisma.user.update.mockResolvedValue({ walletBalance: 100 });
    mockPrisma.transaction.create
      .mockResolvedValueOnce({ id: 'txn-out' })
      .mockResolvedValueOnce({ id: 'txn-in' });

    const res = await request(makeApp())
      .post('/api/v1/user/wallet/transfer')
      .send({ toPhone: '01099999999', amount: 50 });

    expect(res.status).toBe(201);
    expect(res.body.data.recipientName).toBe('Recipient');
    // Verify the conditional updateMany guards balance (the critical race-fix).
    expect(mockPrisma.user.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ id: 'sender-id', walletBalance: { gte: 50 } }),
    }));
    // Two Transaction rows created — debit on sender, credit on recipient.
    expect(mockPrisma.transaction.create).toHaveBeenCalledTimes(2);
    expect(mockNotify).toHaveBeenCalledTimes(2);
  });

  test('rejects invalid phone format', async () => {
    const res = await request(makeApp())
      .post('/api/v1/user/wallet/transfer')
      .send({ toPhone: 'abc', amount: 50 });
    expect(res.status).toBe(400);
  });

  test('rejects amount above max', async () => {
    const res = await request(makeApp())
      .post('/api/v1/user/wallet/transfer')
      .send({ toPhone: '01099999999', amount: 100000 });
    expect(res.status).toBe(400);
  });
});
