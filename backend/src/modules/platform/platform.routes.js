'use strict';
// Phase-2 features: payment numbers, request chat, app settings, client admin tools,
// CSV export, bill admin-amount workflow, and InstaPay / Bank Transfer request types.

const router = require('express').Router();
const { body } = require('express-validator');
const prisma = require('../../config/database');
const { apiResponse, paginate, notifyUser, notifyAdmins, emitToAdmins, emitToUser, logger } = require('../../utils/all');
const { authenticateUser, authenticateAdmin, requireRole, validate } = require('../../middleware/index');

// ═══════════════════════════════════════════════════════════
//  PAYMENT NUMBERS
// ═══════════════════════════════════════════════════════════

// User: list active payment numbers (optionally filtered by type or service)
router.get('/payment-numbers', authenticateUser, async (req, res, next) => {
  try {
    const where = { isActive: true };
    if (req.query.type) where.type = req.query.type;
    if (req.query.serviceId) where.OR = [{ serviceProviderId: req.query.serviceId }, { serviceProviderId: null }];
    const items = await prisma.paymentNumber.findMany({
      where, orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
      select: { id: true, type: true, number: true, label: true, serviceProviderId: true, sortOrder: true },
    });
    return apiResponse.success(res, items);
  } catch (err) { next(err); }
});

// Admin: full CRUD on payment numbers
router.get('/admin/payment-numbers', authenticateAdmin, async (req, res, next) => {
  try {
    const items = await prisma.paymentNumber.findMany({
      orderBy: [{ type: 'asc' }, { sortOrder: 'asc' }],
      include: { serviceProvider: { select: { id: true, displayName: true, category: true } } },
    });
    return apiResponse.success(res, items);
  } catch (err) { next(err); }
});

router.post('/admin/payment-numbers', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  [
    body('type').isIn(['WALLET', 'INSTAPAY', 'BANK']),
    body('number').notEmpty().isLength({ max: 60 }),
    body('label').notEmpty().isLength({ max: 80 }),
    body('serviceProviderId').optional(),
    body('sortOrder').optional().isInt({ min: 0 }),
  ], validate, async (req, res, next) => {
    try {
      const { type, number, label, serviceProviderId, sortOrder } = req.body;
      const item = await prisma.paymentNumber.create({
        data: {
          type, number: number.toString().trim(), label: label.toString().trim(),
          serviceProviderId: serviceProviderId || null,
          sortOrder: sortOrder || 0,
        },
      });
      return apiResponse.success(res, item, 'Payment number added', 201);
    } catch (err) { next(err); }
  }
);

router.put('/admin/payment-numbers/:id', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  async (req, res, next) => {
    try {
      const { type, number, label, serviceProviderId, isActive, sortOrder } = req.body;
      const item = await prisma.paymentNumber.update({
        where: { id: req.params.id },
        data: {
          ...(type !== undefined && { type }),
          ...(number !== undefined && { number: number.toString().trim() }),
          ...(label !== undefined && { label: label.toString().trim() }),
          ...(serviceProviderId !== undefined && { serviceProviderId: serviceProviderId || null }),
          ...(isActive !== undefined && { isActive }),
          ...(sortOrder !== undefined && { sortOrder }),
        },
      });
      return apiResponse.success(res, item, 'Payment number updated');
    } catch (err) { next(err); }
  }
);

router.delete('/admin/payment-numbers/:id', authenticateAdmin, requireRole('SUPER_ADMIN'),
  async (req, res, next) => {
    try {
      await prisma.paymentNumber.delete({ where: { id: req.params.id } });
      return apiResponse.success(res, null, 'Payment number deleted');
    } catch (err) { next(err); }
  }
);

// ═══════════════════════════════════════════════════════════
//  REQUEST MESSAGES (chat per request)
// ═══════════════════════════════════════════════════════════

// User OR admin can fetch messages on a request; both checked via ownership/role.
router.get('/requests/:id/messages', async (req, res, next) => {
  try {
    let userId = null, adminId = null;
    try {
      const { jwtUtils } = require('../../utils/all');
      const h = req.headers.authorization;
      if (h?.startsWith('Bearer ')) {
        try { const a = jwtUtils.verifyAdmin(h.split(' ')[1]); adminId = a.id; }
        catch { const u = jwtUtils.verifyUser(h.split(' ')[1]); userId = u.id; }
      }
    } catch (e) {}
    if (!userId && !adminId) return apiResponse.error(res, 'Unauthorized', 401);

    const r = await prisma.request.findUnique({ where: { id: req.params.id }, select: { userId: true } });
    if (!r) return apiResponse.error(res, 'Not found', 404);
    if (userId && r.userId !== userId) return apiResponse.error(res, 'Forbidden', 403);

    const items = await prisma.requestMessage.findMany({
      where: { requestId: req.params.id },
      orderBy: { createdAt: 'asc' },
      include: {
        user: { select: { id: true, fullName: true } },
        admin: { select: { id: true, fullName: true } },
      },
    });
    // Mark as read for the side that's fetching
    await prisma.requestMessage.updateMany({
      where: { requestId: req.params.id, isRead: false, ...(userId ? { adminId: { not: null } } : { userId: { not: null } }) },
      data: { isRead: true },
    });
    return apiResponse.success(res, items);
  } catch (err) { next(err); }
});

// User posts a message
router.post('/requests/:id/messages', authenticateUser,
  [body('body').notEmpty().isLength({ min: 1, max: 1000 })],
  validate, async (req, res, next) => {
    try {
      const r = await prisma.request.findUnique({ where: { id: req.params.id }, select: { userId: true } });
      if (!r) return apiResponse.error(res, 'Not found', 404);
      if (r.userId !== req.user.id) return apiResponse.error(res, 'Forbidden', 403);
      const msg = await prisma.requestMessage.create({
        data: { requestId: req.params.id, body: req.body.body.toString().trim(), userId: req.user.id },
        include: { user: { select: { id: true, fullName: true } } },
      });
      const io = req.app.get('io');
      emitToAdmins(io, 'request_message', { requestId: req.params.id, message: msg });
      await notifyAdmins('💬 رسالة جديدة على طلب', msg.body.slice(0, 120), 'HIGH', req.params.id, null, { requestId: req.params.id });
      return apiResponse.success(res, msg, 'Sent', 201);
    } catch (err) { next(err); }
  }
);

// Admin posts a message
router.post('/admin/requests/:id/messages', authenticateAdmin,
  [body('body').notEmpty().isLength({ min: 1, max: 1000 })],
  validate, async (req, res, next) => {
    try {
      const r = await prisma.request.findUnique({ where: { id: req.params.id }, select: { userId: true } });
      if (!r) return apiResponse.error(res, 'Not found', 404);
      const msg = await prisma.requestMessage.create({
        data: { requestId: req.params.id, body: req.body.body.toString().trim(), adminId: req.admin.id },
        include: { admin: { select: { id: true, fullName: true } } },
      });
      const io = req.app.get('io');
      emitToUser(io, r.userId, 'request_message', { requestId: req.params.id, message: msg });
      await notifyUser(r.userId, '💬 رسالة جديدة من الدعم', msg.body.slice(0, 120), 'HIGH', { requestId: req.params.id });
      return apiResponse.success(res, msg, 'Sent', 201);
    } catch (err) { next(err); }
  }
);

// ═══════════════════════════════════════════════════════════
//  ADMIN SETTINGS (dynamic app config)
// ═══════════════════════════════════════════════════════════

// User: read public-ish settings (everything except secrets — filtered by key prefix)
router.get('/settings/public', async (req, res, next) => {
  try {
    const items = await prisma.adminSetting.findMany({
      where: { NOT: { key: { startsWith: 'private.' } } },
      orderBy: { key: 'asc' },
    });
    const map = {};
    for (const it of items) map[it.key] = it.value;
    return apiResponse.success(res, map);
  } catch (err) { next(err); }
});

// Admin: read all + bulk update
router.get('/admin/settings', authenticateAdmin, async (req, res, next) => {
  try {
    const items = await prisma.adminSetting.findMany({ orderBy: { key: 'asc' } });
    return apiResponse.success(res, items);
  } catch (err) { next(err); }
});

router.put('/admin/settings', authenticateAdmin, requireRole('SUPER_ADMIN'),
  async (req, res, next) => {
    try {
      const updates = req.body.settings || req.body; // accept either { settings: {...} } or {...}
      const entries = Object.entries(updates).filter(([k]) => /^[a-zA-Z0-9._-]+$/.test(k));
      const results = await Promise.all(entries.map(([key, val]) => {
        const value = typeof val === 'string' ? val : JSON.stringify(val);
        return prisma.adminSetting.upsert({
          where: { key }, update: { value }, create: { key, value },
        });
      }));
      const io = req.app.get('io');
      if (io) io.emit('settings_updated', { keys: results.map(r => r.key) });
      return apiResponse.success(res, results, 'تم تحديث الإعدادات');
    } catch (err) { next(err); }
  }
);

// ═══════════════════════════════════════════════════════════
//  ADMIN — CLIENT MANAGEMENT (search + profile + add-balance)
// ═══════════════════════════════════════════════════════════

// Search by name or phone (partial match)
router.get('/admin/clients', authenticateAdmin, async (req, res, next) => {
  try {
    const { page, limit, skip } = paginate(req.query);
    const search = (req.query.search || '').toString().trim();
    const where = search
      ? { OR: [{ phone: { contains: search } }, { fullName: { contains: search, mode: 'insensitive' } }] }
      : {};
    const [data, total] = await Promise.all([
      prisma.user.findMany({
        where, skip, take: limit, orderBy: { createdAt: 'desc' },
        select: { id: true, phone: true, fullName: true, email: true, type: true, status: true,
          walletBalance: true, pointsBalance: true, payLaterEligible: true, createdAt: true, lastLoginAt: true },
      }),
      prisma.user.count({ where }),
    ]);
    return apiResponse.paginated(res, data, total, page, limit);
  } catch (err) { next(err); }
});

// Admin adds balance to a client wallet (atomic)
router.post('/admin/clients/:id/add-balance', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  [body('amount').isFloat({ min: 1, max: 1000000 }), body('note').optional().isLength({ max: 200 })],
  validate, async (req, res, next) => {
    try {
      const amount = Number(req.body.amount);
      const note = (req.body.note || 'إضافة رصيد بواسطة المسؤول').toString();
      const user = await prisma.user.findUnique({ where: { id: req.params.id }, select: { id: true, fullName: true, walletBalance: true } });
      if (!user) return apiResponse.error(res, 'Not found', 404);
      const result = await prisma.$transaction(async (tx) => {
        const updated = await tx.user.update({
          where: { id: user.id }, data: { walletBalance: { increment: amount } },
          select: { walletBalance: true },
        });
        const txn = await tx.transaction.create({
          data: { userId: user.id, amount, fee: 0, totalAmount: amount, status: 'SUCCESS', paymentMethod: 'ADMIN_CREDIT', externalRef: note },
        });
        await tx.auditLog.create({ data: { adminId: req.admin.id, action: 'ADD_BALANCE', entity: 'user', entityId: user.id, details: `${amount} ج.م — ${note}` } });
        return { newBalance: updated.walletBalance, transactionId: txn.id };
      });
      await notifyUser(user.id, '💰 تم إضافة رصيد لمحفظتك', `تم إضافة ${amount} ج.م بواسطة الإدارة`, 'HIGH');
      return apiResponse.success(res, result, 'تم إضافة الرصيد');
    } catch (err) { next(err); }
  }
);

// ═══════════════════════════════════════════════════════════
//  BILL — admin sets amount, then auto-deduct OR wait for payment proof
// ═══════════════════════════════════════════════════════════

router.put('/admin/requests/:id/set-amount', authenticateAdmin,
  [body('amount').isFloat({ min: 1, max: 1000000 })],
  validate, async (req, res, next) => {
    try {
      const amount = Number(req.body.amount);
      const r = await prisma.request.findUnique({
        where: { id: req.params.id },
        include: { user: { select: { id: true, walletBalance: true, fullName: true } } },
      });
      if (!r) return apiResponse.error(res, 'Not found', 404);
      if (!['PENDING', 'ASSIGNED', 'IN_PROGRESS'].includes(r.status)) {
        return apiResponse.error(res, 'لا يمكن تحديد المبلغ بعد إنهاء الطلب', 400);
      }

      const userBalance = Number(r.user.walletBalance);
      const io = req.app.get('io');

      if (userBalance >= amount) {
        // AUTO-DEDUCT: user has enough → complete immediately
        await prisma.$transaction(async (tx) => {
          await tx.user.update({ where: { id: r.userId }, data: { walletBalance: { decrement: amount } } });
          await tx.request.update({
            where: { id: r.id },
            data: { status: 'COMPLETED', completedAt: new Date(), adminSetAmount: amount, amount, totalAmount: amount, processorId: req.admin.id },
          });
          await tx.transaction.create({
            data: { userId: r.userId, requestId: r.id, amount, fee: 0, totalAmount: amount, status: 'SUCCESS', paymentMethod: 'WALLET_AUTODEDUCT' },
          });
          await tx.auditLog.create({ data: { adminId: req.admin.id, requestId: r.id, action: 'SET_AMOUNT_AUTO_DEDUCT', entity: 'request', entityId: r.id, details: `${amount} ج.م` } });
        });
        emitToUser(io, r.userId, 'request_completed', { requestId: r.id, status: 'COMPLETED' });
        await notifyUser(r.userId, '✅ تم سداد فاتورتك تلقائياً', `تم خصم ${amount} ج.م من محفظتك وسداد الفاتورة`, 'HIGH', { requestId: r.id });
        return apiResponse.success(res, { autoDeducted: true, amount }, 'تم السداد تلقائياً');
      } else {
        // AWAITING_PAYMENT: not enough wallet → user must pay externally
        await prisma.request.update({
          where: { id: r.id },
          data: { status: 'AWAITING_PAYMENT', adminSetAmount: amount, amount, totalAmount: amount },
        });
        emitToUser(io, r.userId, 'request_updated', { requestId: r.id, status: 'AWAITING_PAYMENT', amount });
        await notifyUser(r.userId, '💳 تم تحديد قيمة الفاتورة', `قيمة الفاتورة: ${amount} ج.م. يرجى السداد ورفع إيصال الدفع.`, 'HIGH', { requestId: r.id });
        return apiResponse.success(res, { autoDeducted: false, amount }, 'بانتظار سداد العميل');
      }
    } catch (err) { next(err); }
  }
);

// ═══════════════════════════════════════════════════════════
//  CSV EXPORT (daily completed transactions)
// ═══════════════════════════════════════════════════════════

router.get('/admin/dashboard/export-csv', authenticateAdmin, async (req, res, next) => {
  try {
    const date = req.query.date ? new Date(req.query.date) : new Date();
    const start = new Date(date); start.setHours(0, 0, 0, 0);
    const end = new Date(date); end.setHours(23, 59, 59, 999);
    const txs = await prisma.transaction.findMany({
      where: { createdAt: { gte: start, lte: end } },
      orderBy: { createdAt: 'asc' },
      include: {
        user: { select: { phone: true, fullName: true } },
        request: { select: { type: true, accountNumber: true, phoneNumber: true } },
        serviceProvider: { select: { displayName: true } },
      },
    });
    const escape = (s) => `"${String(s ?? '').replace(/"/g, '""')}"`;
    const rows = [
      ['Date', 'TxnID', 'Status', 'Type', 'Method', 'User Phone', 'User Name', 'Service', 'Account', 'Amount', 'Fee', 'Total'].join(','),
      ...txs.map(t => [
        t.createdAt.toISOString(), t.id, t.status, t.request?.type ?? '', t.paymentMethod ?? '',
        t.user?.phone ?? '', t.user?.fullName ?? '', t.serviceProvider?.displayName ?? '',
        t.request?.accountNumber ?? t.request?.phoneNumber ?? '',
        t.amount, t.fee, t.totalAmount,
      ].map(escape).join(',')),
    ].join('\n');
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="transactions_${date.toISOString().slice(0,10)}.csv"`);
    return res.send('﻿' + rows); // BOM for Excel UTF-8 detection
  } catch (err) { next(err); }
});

module.exports = router;
