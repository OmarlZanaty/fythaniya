'use strict';
const router = require('express').Router();
const { body } = require('express-validator');
const prisma = require('../../config/database');
const {
  apiResponse, paginate, notifyUser, notifyAdmins,
  emitToAdmins, emitToUser, hashPassword, logger,
} = require('../../utils/all');
const { authenticateAdmin, requireRole, validate } = require('../../middleware/index');

// All admin routes require auth
router.use(authenticateAdmin);

// ═══════════════════════════════════════════════════════════
//  DASHBOARD
// ═══════════════════════════════════════════════════════════

router.get('/dashboard', async (req, res, next) => {
  try {
    const today = new Date(); today.setHours(0,0,0,0);

    const [
      totalRequests, pendingRequests, inProgressRequests,
      completedToday, failedToday, slaBreach,
      totalUsers, newUsersToday, b2bPending, b2bOverdue,
      totalRevenue,
    ] = await Promise.all([
      prisma.request.count(),
      prisma.request.count({ where: { status: 'PENDING' } }),
      prisma.request.count({ where: { status: 'IN_PROGRESS' } }),
      prisma.request.count({ where: { status: 'COMPLETED', completedAt: { gte: today } } }),
      prisma.request.count({ where: { status: 'FAILED', updatedAt: { gte: today } } }),
      prisma.request.count({ where: { status: { in: ['PENDING','IN_PROGRESS'] }, slaDeadline: { lt: new Date() } } }),
      prisma.user.count(),
      prisma.user.count({ where: { createdAt: { gte: today } } }),
      prisma.b2BAccount.count({ where: { payLaterStatus: 'PENDING_APPROVAL' } }),
      prisma.b2BPayLater.count({ where: { status: 'OVERDUE' } }),
      prisma.transaction.aggregate({ where: { status: 'SUCCESS' }, _sum: { totalAmount: true } }),
    ]);

    return apiResponse.success(res, {
      requests: { total: totalRequests, pending: pendingRequests, inProgress: inProgressRequests, completedToday, failedToday, slaBreach },
      users: { total: totalUsers, newToday: newUsersToday },
      b2b: { pendingApplications: b2bPending, overdueInvoices: b2bOverdue },
      revenue: { total: Number(totalRevenue._sum.totalAmount) || 0 },
    });
  } catch (err) { next(err); }
});

// ═══════════════════════════════════════════════════════════
//  REQUESTS QUEUE
// ═══════════════════════════════════════════════════════════

router.get('/requests', async (req, res, next) => {
  try {
    const { page, limit, skip } = paginate(req.query);
    const where = {};
    if (req.query.status) where.status = req.query.status;
    if (req.query.type)   where.type   = req.query.type;
    if (req.query.search) where.OR = [
      { user: { phone: { contains: req.query.search } } },
      { user: { fullName: { contains: req.query.search, mode: 'insensitive' } } },
      { accountNumber: { contains: req.query.search } },
    ];

    const [data, total] = await Promise.all([
      prisma.request.findMany({
        where, skip, take: limit,
        orderBy: [{ status: 'asc' }, { slaDeadline: 'asc' }, { createdAt: 'asc' }],
        include: {
          user: { select: { id: true, phone: true, fullName: true, type: true } },
          serviceProvider: { select: { id: true, displayName: true, category: true } },
          subService: { select: { id: true, nameAr: true } },
          processor: { select: { id: true, fullName: true } },
        },
      }),
      prisma.request.count({ where }),
    ]);
    return apiResponse.paginated(res, data, total, page, limit);
  } catch (err) { next(err); }
});

router.get('/requests/:id', async (req, res, next) => {
  try {
    const r = await prisma.request.findUnique({
      where: { id: req.params.id },
      include: {
        user: { select: { id: true, phone: true, fullName: true, email: true, type: true, status: true, kycVerified: true, pointsBalance: true, walletBalance: true } },
        serviceProvider: true,
        subService: true,
        processor: { select: { id: true, fullName: true, email: true } },
        transactions: true,
        escalations: true,
        auditLogs: { orderBy: { createdAt: 'asc' } },
        b2bPayLater: { include: { b2bAccount: { include: { user: { select: { id: true, phone: true, fullName: true } } } } } },
      },
    });
    if (!r) return apiResponse.error(res, 'Not found', 404);
    return apiResponse.success(res, r);
  } catch (err) { next(err); }
});

// Assign to self (optimistic-lock: only succeeds if request is still PENDING/ASSIGNED)
router.put('/requests/:id/assign', async (req, res, next) => {
  try {
    const upd = await prisma.request.updateMany({
      where: { id: req.params.id, status: { in: ['PENDING','ASSIGNED'] } },
      data: { status: 'ASSIGNED', processorId: req.admin.id },
    });
    if (upd.count === 0) return apiResponse.error(res, 'الطلب غير متاح للتعيين (تم التعيين من قِبل مسؤول آخر أو تغيرت حالته)', 409);
    const r = await prisma.request.findUnique({ where: { id: req.params.id } });
    const io = req.app.get('io');
    emitToAdmins(io, 'request_updated', { requestId: r.id, status: 'ASSIGNED', processorId: req.admin.id });
    emitToUser(io, r.userId, 'request_updated', { requestId: r.id, status: 'ASSIGNED' });
    await notifyUser(r.userId, '👤 تم استلام طلبك', 'تم تعيين موظف لمعالجة طلبك', 'NORMAL', { requestId: r.id, status: 'ASSIGNED' });
    await prisma.auditLog.create({ data: { adminId: req.admin.id, requestId: r.id, action: 'ASSIGN', entity: 'request', entityId: r.id } });
    return apiResponse.success(res, r, 'تم التعيين');
  } catch (err) { next(err); }
});

// Mark IN_PROGRESS
router.put('/requests/:id/start', async (req, res, next) => {
  try {
    const r = await prisma.request.findUnique({ where: { id: req.params.id } });
    if (!r) return apiResponse.error(res, 'Not found', 404);
    const updated = await prisma.request.update({ where: { id: r.id }, data: { status: 'IN_PROGRESS', processorId: req.admin.id } });
    const io = req.app.get('io');
    emitToAdmins(io, 'request_updated', { requestId: r.id, status: 'IN_PROGRESS' });
    emitToUser(io, r.userId, 'request_updated', { requestId: r.id, status: 'IN_PROGRESS' });
    await notifyUser(r.userId, '⏳ جارٍ تنفيذ طلبك', 'بدأ معالج المعاملات بتنفيذ طلبك الآن', 'NORMAL', { requestId: r.id, status: 'IN_PROGRESS' });
    return apiResponse.success(res, updated);
  } catch (err) { next(err); }
});

// Complete request ✅
router.put('/requests/:id/complete', requireRole('TRANSACTION_PROCESSOR','B2B_MANAGER','SUPER_ADMIN'),
  [body('externalRef').optional()],
  async (req, res, next) => {
    try {
      const { externalRef, adminNote } = req.body;
      const r = await prisma.request.findUnique({
        where: { id: req.params.id },
        include: {
          user: { select: { id: true, phone: true, fullName: true, deviceToken: true } },
          serviceProvider: { select: { id: true, category: true } },
        },
      });
      if (!r) return apiResponse.error(res, 'Not found', 404);
      if (['COMPLETED','FAILED','REFUNDED'].includes(r.status)) return apiResponse.error(res, 'Already finalized', 400);

      await prisma.$transaction(async (tx) => {
        await tx.request.update({
          where: { id: r.id },
          data: { status: 'COMPLETED', completedAt: new Date(), externalRef: externalRef || null, adminNote: adminNote || null, processorId: req.admin.id },
        });

        // Side-effects branch by request type
        if (r.type === 'WALLET_TOPUP') {
          // Credit wallet only on approval; record TOPUP transaction
          await tx.user.update({ where: { id: r.userId }, data: { walletBalance: { increment: Number(r.amount) } } });
          await tx.transaction.create({
            data: { userId: r.userId, requestId: r.id, amount: r.amount, fee: 0, totalAmount: r.amount,
              status: 'SUCCESS', paymentMethod: r.paymentMethod || 'TOPUP', externalRef: externalRef || null },
          });
        } else if (r.type === 'PAY_LATER_ACTIVATION') {
          // Flip the eligibility flag
          await tx.user.update({ where: { id: r.userId }, data: { payLaterEligible: true, payLaterApprovedAt: new Date() } });
          // No financial transaction row needed
        } else {
          // Regular service request — create the service-pay transaction
          await tx.transaction.create({
            data: { userId: r.userId, requestId: r.id, serviceProviderId: r.serviceProviderId,
              amount: r.amount, fee: r.fee, totalAmount: r.totalAmount,
              status: 'SUCCESS', paymentMethod: 'WALLET', externalRef: externalRef || null },
          });
          // Reward points: 1 point per 100 EGP, capped at 50 per transaction (was 1pt/10 EGP).
          const pts = Math.min(50, Math.floor(Number(r.amount) / 100));
          if (pts > 0) {
            await tx.user.update({ where: { id: r.userId }, data: { pointsBalance: { increment: pts } } });
            await tx.rewardTransaction.create({ data: { userId: r.userId, points: pts, isEarned: true, reason: 'مكافأة معاملة', referenceId: r.id } });
          }
          // Spending record
          if (r.serviceProvider) {
            const monthKey = `${new Date().getFullYear()}-${String(new Date().getMonth()+1).padStart(2,'0')}`;
            await tx.spendingRecord.upsert({
              where: { userId_category_month_year: { userId: r.userId, category: r.serviceProvider.category, month: monthKey, year: new Date().getFullYear() } },
              update: { amount: { increment: Number(r.amount) }, count: { increment: 1 } },
              create: { userId: r.userId, category: r.serviceProvider.category, month: monthKey, year: new Date().getFullYear(), amount: r.amount, count: 1 },
            });
          }
        }
      });

      const io = req.app.get('io');
      emitToAdmins(io, 'request_updated', { requestId: r.id, status: 'COMPLETED' });
      emitToUser(io, r.userId, 'request_completed', { requestId: r.id, status: 'COMPLETED' });

      const successTitle = r.type === 'WALLET_TOPUP' ? '💰 تم شحن محفظتك'
        : r.type === 'PAY_LATER_ACTIVATION' ? '✅ تم تفعيل الدفع الآجل'
        : '✅ تم تنفيذ طلبك';
      const successBody = r.type === 'WALLET_TOPUP' ? `تم إضافة ${r.amount} ج.م إلى محفظتك`
        : r.type === 'PAY_LATER_ACTIVATION' ? 'يمكنك الآن استخدام خدمة الدفع الآجل'
        : `تم إتمام طلبك بنجاح${externalRef ? '. رقم المرجع: ' + externalRef : ''}`;
      await notifyUser(r.userId, successTitle, successBody, 'HIGH', { requestId: r.id });

      await prisma.auditLog.create({ data: { adminId: req.admin.id, requestId: r.id, action: 'COMPLETE', entity: 'request', entityId: r.id, details: externalRef } });
      return apiResponse.success(res, null, 'تم إتمام الطلب بنجاح');
    } catch (err) { next(err); }
  }
);

// Fail request ❌
router.put('/requests/:id/fail', requireRole('TRANSACTION_PROCESSOR','B2B_MANAGER','SUPER_ADMIN'),
  [body('reason').notEmpty().withMessage('سبب الفشل مطلوب')],
  validate,
  async (req, res, next) => {
    try {
      const { reason } = req.body;
      const r = await prisma.request.findUnique({ where: { id: req.params.id } });
      if (!r) return apiResponse.error(res, 'Not found', 404);
      if (['COMPLETED','FAILED','REFUNDED'].includes(r.status)) return apiResponse.error(res, 'Already finalized', 400);

      await prisma.$transaction(async (tx) => {
        await tx.request.update({ where: { id: r.id }, data: { status: 'FAILED', adminNote: reason } });
        await tx.transaction.create({
          data: {
            userId: r.userId, requestId: r.id,
            amount: r.amount, fee: r.fee, totalAmount: r.totalAmount,
            status: 'FAILED', paymentMethod: 'WALLET',
          },
        });
        // Refund if B2B Pay Later
        if (r.type === 'B2B_PAY_LATER') {
          const pl = await tx.b2BPayLater.findFirst({ where: { requestId: r.id } });
          if (pl) {
            await tx.b2BPayLater.update({ where: { id: pl.id }, data: { status: 'SETTLED', settledAt: new Date() } });
            await tx.b2BAccount.update({ where: { id: pl.b2bAccountId }, data: { usedCredit: { decrement: Number(pl.amount) } } });
          }
        }
      });

      const io = req.app.get('io');
      emitToAdmins(io, 'request_updated', { requestId: r.id, status: 'FAILED' });
      emitToUser(io, r.userId, 'request_failed', { requestId: r.id, reason });

      await notifyUser(r.userId, '❌ لم يتم تنفيذ طلبك', `عذراً، لم يتم تنفيذ طلبك. السبب: ${reason}`, 'HIGH', { requestId: r.id });
      await prisma.auditLog.create({ data: { adminId: req.admin.id, requestId: r.id, action: 'FAIL', entity: 'request', entityId: r.id, details: reason } });
      return apiResponse.success(res, null, 'تم تحديث الطلب');
    } catch (err) { next(err); }
  }
);

// Refund and Escalate endpoints removed — admins now only Approve (complete) or Reject (fail).
// Auto-escalation still runs via the SLA cron job (jobs.js) for monitoring purposes.

// Add admin note
router.put('/requests/:id/note', requireRole('TRANSACTION_PROCESSOR','B2B_MANAGER','SUPER_ADMIN'), async (req, res, next) => {
  try {
    const { note } = req.body;
    if (!note) return apiResponse.error(res, 'Note required', 400);
    await prisma.request.update({ where: { id: req.params.id }, data: { adminNote: note } });
    return apiResponse.success(res, null, 'Note saved');
  } catch (err) { next(err); }
});

// ═══════════════════════════════════════════════════════════
//  USERS MANAGEMENT
// ═══════════════════════════════════════════════════════════

router.get('/users', async (req, res, next) => {
  try {
    const { page, limit, skip } = paginate(req.query);
    const where = {};
    if (req.query.type)   where.type   = req.query.type;
    if (req.query.status) where.status = req.query.status;
    if (req.query.search) where.OR = [
      { phone: { contains: req.query.search } },
      { fullName: { contains: req.query.search, mode: 'insensitive' } },
    ];
    const [data, total] = await Promise.all([
      prisma.user.findMany({
        where, skip, take: limit, orderBy: { createdAt: 'desc' },
        select: { id:true, phone:true, fullName:true, email:true, type:true, status:true, walletBalance:true, pointsBalance:true, createdAt:true, lastLoginAt:true },
      }),
      prisma.user.count({ where }),
    ]);
    return apiResponse.paginated(res, data, total, page, limit);
  } catch (err) { next(err); }
});

router.get('/users/:id', async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.params.id },
      select: {
        id: true, phone: true, fullName: true, email: true, nationalId: true,
        type: true, status: true, kycVerified: true, kycVerifiedAt: true,
        pointsBalance: true, walletBalance: true, createdAt: true, lastLoginAt: true,
        b2bAccount: true,
        userNotifications: { take: 10, orderBy: { createdAt: 'desc' } },
      },
    });
    if (!user) return apiResponse.error(res, 'Not found', 404);
    const [requests, transactions] = await Promise.all([
      prisma.request.findMany({ where: { userId: user.id }, take: 10, orderBy: { createdAt: 'desc' } }),
      prisma.transaction.findMany({ where: { userId: user.id }, take: 10, orderBy: { createdAt: 'desc' } }),
    ]);
    return apiResponse.success(res, { ...user, recentRequests: requests, recentTransactions: transactions });
  } catch (err) { next(err); }
});

router.put('/users/:id/status', requireRole('SUPER_ADMIN'),
  [body('status').isIn(['ACTIVE','SUSPENDED','BANNED'])], validate,
  async (req, res, next) => {
    try {
      const exists = await prisma.user.findUnique({ where: { id: req.params.id }, select: { id: true } });
      if (!exists) return apiResponse.error(res, 'User not found', 404);
      await prisma.user.update({ where: { id: req.params.id }, data: { status: req.body.status } });
      await prisma.auditLog.create({ data: { adminId: req.admin.id, userId: req.params.id, action: 'UPDATE_STATUS', entity: 'user', entityId: req.params.id, details: req.body.status } });
      return apiResponse.success(res, null, 'تم تحديث حالة المستخدم');
    } catch (err) { next(err); }
  }
);

// ═══════════════════════════════════════════════════════════
//  ADMIN NOTIFICATIONS
// ═══════════════════════════════════════════════════════════

router.get('/notifications', async (req, res, next) => {
  try {
    const { page, limit, skip } = paginate(req.query);
    const [data, total, unreadCount] = await Promise.all([
      prisma.adminNotification.findMany({
        where: { adminId: req.admin.id },
        skip, take: limit, orderBy: { createdAt: 'desc' },
      }),
      prisma.adminNotification.count({ where: { adminId: req.admin.id } }),
      prisma.adminNotification.count({ where: { adminId: req.admin.id, isRead: false } }),
    ]);
    return res.json({ success: true, data, pagination: { total, page, limit, totalPages: Math.ceil(total/limit) }, unreadCount });
  } catch (err) { next(err); }
});

router.put('/notifications/read-all', async (req, res, next) => {
  try {
    await prisma.adminNotification.updateMany({
      where: { adminId: req.admin.id, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
    return apiResponse.success(res, null, 'All marked as read');
  } catch (err) { next(err); }
});

router.put('/notifications/:id/read', async (req, res, next) => {
  try {
    await prisma.adminNotification.update({
      where: { id: req.params.id },
      data: { isRead: true, readAt: new Date() },
    });
    return apiResponse.success(res, null, 'Marked as read');
  } catch (err) { next(err); }
});

// ═══════════════════════════════════════════════════════════
//  ADMIN MANAGEMENT (SUPER_ADMIN only)
// ═══════════════════════════════════════════════════════════

router.get('/admins', requireRole('SUPER_ADMIN'), async (req, res, next) => {
  try {
    const admins = await prisma.admin.findMany({
      select: { id:true, email:true, fullName:true, role:true, isActive:true, lastLoginAt:true, createdAt:true },
    });
    return apiResponse.success(res, admins);
  } catch (err) { next(err); }
});

router.post('/admins', requireRole('SUPER_ADMIN'),
  [body('email').isEmail(), body('password').isLength({ min:6 }), body('fullName').notEmpty(),
   body('role').isIn(['SUPER_ADMIN','TRANSACTION_PROCESSOR','B2B_MANAGER','SUPPORT_AGENT'])],
  validate,
  async (req, res, next) => {
    try {
      const { email, password, fullName, role } = req.body;
      const hash = await hashPassword(password);
      const admin = await prisma.admin.create({ data: { email, passwordHash: hash, fullName, role } });
      return apiResponse.success(res, { id: admin.id, email: admin.email, role: admin.role }, 'Admin created', 201);
    } catch (err) { next(err); }
  }
);

router.put('/admins/:id', requireRole('SUPER_ADMIN'), async (req, res, next) => {
  try {
    const { fullName, role, isActive } = req.body;
    await prisma.admin.update({
      where: { id: req.params.id },
      data: {
        ...(fullName !== undefined && { fullName }),
        ...(role     !== undefined && { role }),
        ...(isActive !== undefined && { isActive }),
      },
    });
    return apiResponse.success(res, null, 'Admin updated');
  } catch (err) { next(err); }
});

// ═══════════════════════════════════════════════════════════
//  SYSTEM CONFIG
// ═══════════════════════════════════════════════════════════

router.get('/config', requireRole('SUPER_ADMIN'), async (req, res, next) => {
  try {
    const configs = await prisma.systemConfig.findMany({ orderBy: { key: 'asc' } });
    return apiResponse.success(res, configs);
  } catch (err) { next(err); }
});

router.put('/config/:key', requireRole('SUPER_ADMIN'),
  [body('value').notEmpty()], validate,
  async (req, res, next) => {
    try {
      const cfg = await prisma.systemConfig.upsert({
        where: { key: req.params.key },
        update: { value: req.body.value, updatedBy: req.admin.id },
        create: { key: req.params.key, value: req.body.value, updatedBy: req.admin.id },
      });
      return apiResponse.success(res, cfg, 'Config updated');
    } catch (err) { next(err); }
  }
);

// ═══════════════════════════════════════════════════════════
//  ANALYTICS
// ═══════════════════════════════════════════════════════════

router.get('/analytics/overview', async (req, res, next) => {
  try {
    const days = parseInt(req.query.days) || 30;
    const from = new Date(Date.now() - days * 86400000);

    const [byStatus, byType, revenueByDay] = await Promise.all([
      prisma.request.groupBy({ by: ['status'], _count: { _all: true }, where: { createdAt: { gte: from } } }),
      prisma.request.groupBy({ by: ['type'], _count: { _all: true }, _sum: { amount: true }, where: { createdAt: { gte: from } } }),
      prisma.transaction.findMany({
        where: { status: 'SUCCESS', createdAt: { gte: from } },
        select: { createdAt: true, totalAmount: true },
        orderBy: { createdAt: 'asc' },
      }),
    ]);

    return apiResponse.success(res, { byStatus, byType, revenueByDay });
  } catch (err) { next(err); }
});

// ═══════════════════════════════════════════════════════════
//  REPORTS
// ═══════════════════════════════════════════════════════════

function rangeFromQuery(q) {
  const to = q.to ? new Date(q.to) : new Date();
  const from = q.from ? new Date(q.from) : new Date(to.getTime() - 30 * 86400000);
  return { from, to };
}

// Aggregate transactions over a period: counts + sums by type and by status
router.get('/reports/transactions', async (req, res, next) => {
  try {
    const { from, to } = rangeFromQuery(req.query);
    const where = { createdAt: { gte: from, lte: to } };
    const [byStatus, byMethod, totalsRaw] = await Promise.all([
      prisma.transaction.groupBy({ by: ['status'], where, _count: { _all: true }, _sum: { totalAmount: true } }),
      prisma.transaction.groupBy({ by: ['paymentMethod'], where, _count: { _all: true }, _sum: { totalAmount: true } }),
      prisma.transaction.aggregate({ where, _count: { _all: true }, _sum: { totalAmount: true, fee: true } }),
    ]);
    return apiResponse.success(res, {
      from, to,
      totals: { count: totalsRaw._count._all, totalAmount: totalsRaw._sum.totalAmount, totalFee: totalsRaw._sum.fee },
      byStatus, byMethod,
    });
  } catch (err) { next(err); }
});

// Pay-later report: per-account outstanding/active/overdue + per-invoice listing
router.get('/reports/pay-later', requireRole('SUPER_ADMIN','B2B_MANAGER'), async (req, res, next) => {
  try {
    const status = req.query.status; // ACTIVE | OVERDUE | SETTLED
    const where = status ? { status } : {};
    const [perInvoice, summary] = await Promise.all([
      prisma.b2BPayLater.findMany({
        where, orderBy: { dueDate: 'asc' }, take: 200,
        include: { b2bAccount: { include: { user: { select: { id: true, phone: true, fullName: true } } } }, request: { select: { id: true, type: true } } },
      }),
      prisma.b2BPayLater.groupBy({ by: ['status'], _count: { _all: true }, _sum: { amount: true } }),
    ]);
    return apiResponse.success(res, { invoices: perInvoice, summary });
  } catch (err) { next(err); }
});

// Mark a pay-later invoice as settled (admin overrides — useful when user pays offline)
router.put('/reports/pay-later/:id/mark-settled', requireRole('SUPER_ADMIN','B2B_MANAGER'), async (req, res, next) => {
  try {
    const pl = await prisma.b2BPayLater.findUnique({ where: { id: req.params.id }, include: { b2bAccount: true } });
    if (!pl) return apiResponse.error(res, 'Not found', 404);
    if (pl.status === 'SETTLED') return apiResponse.error(res, 'مسددة بالفعل', 409);
    await prisma.$transaction([
      prisma.b2BPayLater.update({ where: { id: pl.id }, data: { status: 'SETTLED', settledAt: new Date() } }),
      prisma.b2BAccount.update({ where: { id: pl.b2bAccountId }, data: { usedCredit: { decrement: Number(pl.amount) } } }),
      prisma.auditLog.create({ data: { adminId: req.admin.id, action: 'MARK_SETTLED', entity: 'b2b_pay_later', entityId: pl.id } }),
    ]);
    return apiResponse.success(res, null, 'تم تسجيل السداد');
  } catch (err) { next(err); }
});

// User payment history (for reports drill-down)
router.get('/reports/user/:id/history', async (req, res, next) => {
  try {
    const { from, to } = rangeFromQuery(req.query);
    const userId = req.params.id;
    const [requests, transactions] = await Promise.all([
      prisma.request.findMany({
        where: { userId, createdAt: { gte: from, lte: to } },
        orderBy: { createdAt: 'desc' }, take: 200,
        include: { serviceProvider: { select: { id: true, displayName: true, category: true } }, subService: { select: { id: true, nameAr: true } } },
      }),
      prisma.transaction.findMany({
        where: { userId, createdAt: { gte: from, lte: to } },
        orderBy: { createdAt: 'desc' }, take: 200,
      }),
    ]);
    return apiResponse.success(res, { from, to, requests, transactions });
  } catch (err) { next(err); }
});

// Audit logs
router.get('/audit-logs', requireRole('SUPER_ADMIN'), async (req, res, next) => {
  try {
    const { page, limit, skip } = paginate(req.query);
    const [data, total] = await Promise.all([
      prisma.auditLog.findMany({
        skip, take: limit, orderBy: { createdAt: 'desc' },
        include: { admin: { select: { fullName: true } } },
      }),
      prisma.auditLog.count(),
    ]);
    return apiResponse.paginated(res, data, total, page, limit);
  } catch (err) { next(err); }
});

module.exports = router;
