'use strict';
const router = require('express').Router();
const { body } = require('express-validator');
const prisma = require('../../config/database');
const { apiResponse, paginate, notifyUser, notifyAdmins, emitToAdmins } = require('../../utils/all');
const { authenticateUser, authenticateAdmin, requireRole, validate } = require('../../middleware/index');

// ═══════════════════════════════════════════════════════════
//  USER B2B ROUTES
// ═══════════════════════════════════════════════════════════

// POST /b2b/apply — apply for B2B account + Pay Later
router.post('/apply', authenticateUser,
  [
    body('companyName').notEmpty().withMessage('اسم الشركة مطلوب'),
    body('taxId').notEmpty().withMessage('الرقم الضريبي مطلوب'),
    body('commercialReg').optional(),
    body('contactName').notEmpty().withMessage('اسم جهة الاتصال مطلوب'),
    body('contactPhone').notEmpty().withMessage('هاتف جهة الاتصال مطلوب'),
    body('requestedLimit').isFloat({ min: 100 }).withMessage('الحد الائتماني غير صحيح'),
  ], validate,
  async (req, res, next) => {
    try {
      const existing = await prisma.b2BAccount.findUnique({ where: { userId: req.user.id } });
      if (existing) return apiResponse.error(res, 'لديك حساب B2B بالفعل', 409);

      const { companyName, taxId, commercialReg, contactName, contactPhone, requestedLimit } = req.body;

      const account = await prisma.b2BAccount.create({
        data: {
          userId: req.user.id,
          companyName, taxId,
          commercialReg: commercialReg || null,
          contactName, contactPhone,
          creditLimit: 0,
          usedCredit: 0,
          payLaterStatus: 'PENDING_APPROVAL',
        },
      });

      await prisma.user.update({ where: { id: req.user.id }, data: { type: 'B2B' } });

      // Notify admins
      const io = req.app.get('io');
      await notifyAdmins(
        '🏢 طلب B2B جديد',
        `${companyName} تطلب حساب B2B بحد ${requestedLimit} ج.م`,
        'CRITICAL', null, ['SUPER_ADMIN', 'B2B_MANAGER'],
        { requestedLimit: String(requestedLimit), companyName }
      );
      emitToAdmins(io, 'b2b_application', { accountId: account.id, companyName, requestedLimit });

      await notifyUser(req.user.id, '✅ تم استلام طلبك', 'جارٍ مراجعة طلب حساب B2B الخاص بك. سيتم الرد خلال 24 ساعة.', 'HIGH');

      return apiResponse.success(res, account, 'تم تقديم الطلب بنجاح', 201);
    } catch (err) { next(err); }
  }
);

// GET /b2b/account — get own B2B account
router.get('/account', authenticateUser, async (req, res, next) => {
  try {
    const account = await prisma.b2BAccount.findUnique({
      where: { userId: req.user.id },
      include: {
        b2bPayLaters: { orderBy: { createdAt: 'desc' }, take: 20 },
        groupPayments: { orderBy: { createdAt: 'desc' }, take: 10 },
      },
    });
    if (!account) return apiResponse.error(res, 'لا يوجد حساب B2B', 404);
    return apiResponse.success(res, {
      ...account,
      availableCredit: Number(account.creditLimit) - Number(account.usedCredit),
    });
  } catch (err) { next(err); }
});

// GET /b2b/pay-laters — list own Pay Later invoices
router.get('/pay-laters', authenticateUser, async (req, res, next) => {
  try {
    const { page, limit, skip } = paginate(req.query);
    const account = await prisma.b2BAccount.findUnique({ where: { userId: req.user.id } });
    if (!account) return apiResponse.error(res, 'لا يوجد حساب B2B', 404);

    const where = { b2bAccountId: account.id };
    if (req.query.status) where.status = req.query.status;

    const [data, total] = await Promise.all([
      prisma.b2BPayLater.findMany({
        where, skip, take: limit, orderBy: { createdAt: 'desc' },
        include: { request: { include: { serviceProvider: true } } },
      }),
      prisma.b2BPayLater.count({ where }),
    ]);
    return apiResponse.paginated(res, data, total, page, limit);
  } catch (err) { next(err); }
});

// POST /b2b/request — create B2B Pay Later request
router.post('/request', authenticateUser,
  [
    body('serviceProviderId').notEmpty(),
    body('subServiceId').optional(),
    body('amount').isFloat({ min: 1 }),
    body('accountNumber').notEmpty().withMessage('رقم الحساب مطلوب'),
    body('phoneNumber').optional(),
  ], validate,
  async (req, res, next) => {
    try {
      const account = await prisma.b2BAccount.findUnique({ where: { userId: req.user.id } });
      if (!account) return apiResponse.error(res, 'لا يوجد حساب B2B', 404);
      if (account.payLaterStatus !== 'ACTIVE') return apiResponse.error(res, 'حساب Pay Later غير مفعّل', 403);

      const { serviceProviderId, subServiceId, amount, accountNumber, phoneNumber } = req.body;
      const available = Number(account.creditLimit) - Number(account.usedCredit);
      if (amount > available) return apiResponse.error(res, `الحد المتاح: ${available} ج.م`, 400);

      // Get fee
      let fee = 0;
      if (subServiceId) {
        const sub = await prisma.subService.findUnique({ where: { id: subServiceId } });
        if (sub) fee = Number(sub.fixedFee) + (amount * Number(sub.percentageFee));
      }

      const totalAmount = amount + fee;
      const io = req.app.get('io');

      const result = await prisma.$transaction(async (tx) => {
        const request = await tx.request.create({
          data: {
            userId: req.user.id, serviceProviderId, subServiceId: subServiceId || null,
            type: 'B2B_PAY_LATER', status: 'PENDING',
            amount, fee, totalAmount, accountNumber, phoneNumber: phoneNumber || null,
            slaDeadline: new Date(Date.now() + 5 * 60 * 1000), // 5 min SLA for B2B
          },
        });

        const dueDate = new Date(Date.now() + account.paymentTermDays * 86400000);
        const invoiceNo = `INV-${Date.now()}-${Math.random().toString(36).slice(2,6).toUpperCase()}`;

        const payLater = await tx.b2BPayLater.create({
          data: {
            b2bAccountId: account.id, requestId: request.id,
            amount: totalAmount, dueDate, status: 'ACTIVE', invoiceNo,
          },
        });

        await tx.b2BAccount.update({
          where: { id: account.id },
          data: { usedCredit: { increment: totalAmount } },
        });

        return { request, payLater };
      });

      await notifyAdmins(
        '💼 طلب B2B جديد - عاجل',
        `طلب Pay Later بمبلغ ${totalAmount} ج.م — ${account.companyName}`,
        'CRITICAL', result.request.id, ['SUPER_ADMIN', 'B2B_MANAGER', 'TRANSACTION_PROCESSOR'],
        { requestId: result.request.id, amount: String(totalAmount) }
      );
      emitToAdmins(io, 'new_request', {
        requestId: result.request.id, type: 'B2B_PAY_LATER',
        amount: totalAmount, companyName: account.companyName,
      });

      return apiResponse.success(res, result, 'تم تقديم الطلب بنجاح', 201);
    } catch (err) { next(err); }
  }
);

// POST /b2b/group-payment — initiate a group payment
router.post('/group-payment', authenticateUser,
  [
    body('memberIds').isArray({ min: 1 }).withMessage('يجب إضافة أعضاء'),
    body('amounts').isArray({ min: 1 }),
    body('dueDate').isISO8601().withMessage('تاريخ الاستحقاق غير صحيح'),
  ], validate,
  async (req, res, next) => {
    try {
      const account = await prisma.b2BAccount.findUnique({ where: { userId: req.user.id } });
      if (!account || account.payLaterStatus !== 'ACTIVE') return apiResponse.error(res, 'حساب B2B غير مفعّل', 403);

      const { memberIds, amounts, dueDate } = req.body;
      if (memberIds.length !== amounts.length) return apiResponse.error(res, 'عدد الأعضاء يجب أن يطابق عدد المبالغ', 400);
      if (amounts.some(a => Number(a) <= 0 || !isFinite(Number(a)))) return apiResponse.error(res, 'مبلغ غير صحيح', 400);
      const totalAmount = amounts.reduce((s, a) => s + Number(a), 0);
      if (totalAmount > 250000) return apiResponse.error(res, 'إجمالي المبلغ يتجاوز الحد المسموح', 400);

      const group = await prisma.$transaction(async (tx) => {
        const gp = await tx.groupPayment.create({
          data: { b2bId: account.id, totalAmount, dueDate: new Date(dueDate), status: 'PENDING' },
        });
        const members = memberIds.map((uid, i) => ({
          groupId: gp.id, userId: uid, amount: Number(amounts[i]) || 0,
        }));
        await tx.groupPaymentMember.createMany({ data: members });
        return gp;
      });

      // Notify each member
      for (const uid of memberIds) {
        await notifyUser(uid, '💳 طلب دفع جماعي', `${account.companyName} أضافك لطلب دفع بمبلغ ${totalAmount} ج.م`, 'HIGH');
      }

      return apiResponse.success(res, group, 'تم إنشاء الدفع الجماعي', 201);
    } catch (err) { next(err); }
  }
);

// POST /b2b/settle/:payLaterId — mark pay later as settled (user paying back)
router.post('/settle/:payLaterId', authenticateUser, async (req, res, next) => {
  try {
    const pl = await prisma.b2BPayLater.findFirst({
      where: { id: req.params.payLaterId },
      include: { b2bAccount: true },
    });
    if (!pl || pl.b2bAccount.userId !== req.user.id) return apiResponse.error(res, 'Not found', 404);
    if (pl.status === 'SETTLED') return apiResponse.error(res, 'مدفوعة مسبقاً', 400);

    await prisma.$transaction([
      prisma.b2BPayLater.update({ where: { id: pl.id }, data: { status: 'SETTLED', settledAt: new Date() } }),
      prisma.b2BAccount.update({ where: { id: pl.b2bAccountId }, data: { usedCredit: { decrement: Number(pl.amount) } } }),
    ]);

    await notifyAdmins('💰 سداد Pay Later', `تم سداد فاتورة ${pl.invoiceNo} بمبلغ ${pl.amount} ج.م`, 'HIGH', null, ['SUPER_ADMIN', 'B2B_MANAGER']);
    return apiResponse.success(res, null, 'تم تسجيل السداد');
  } catch (err) { next(err); }
});

// ═══════════════════════════════════════════════════════════
//  ADMIN B2B ROUTES
// ═══════════════════════════════════════════════════════════

// GET /b2b/admin/applications — pending B2B applications
router.get('/admin/applications', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  async (req, res, next) => {
    try {
      const { page, limit, skip } = paginate(req.query);
      const where = {};
      if (req.query.status) where.payLaterStatus = req.query.status;
      else where.payLaterStatus = 'PENDING_APPROVAL';

      const [data, total] = await Promise.all([
        prisma.b2BAccount.findMany({
          where, skip, take: limit, orderBy: { createdAt: 'desc' },
          include: { user: { select: { id: true, phone: true, fullName: true, email: true } } },
        }),
        prisma.b2BAccount.count({ where }),
      ]);
      return apiResponse.paginated(res, data, total, page, limit);
    } catch (err) { next(err); }
  }
);

// GET /b2b/admin/accounts — all B2B accounts
router.get('/admin/accounts', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  async (req, res, next) => {
    try {
      const { page, limit, skip } = paginate(req.query);
      const where = { payLaterStatus: { not: 'PENDING_APPROVAL' } };
      if (req.query.status) where.payLaterStatus = req.query.status;

      const [data, total] = await Promise.all([
        prisma.b2BAccount.findMany({
          where, skip, take: limit, orderBy: { createdAt: 'desc' },
          include: {
            user: { select: { id: true, phone: true, fullName: true } },
            b2bPayLaters: { where: { status: { in: ['ACTIVE', 'OVERDUE'] } }, select: { amount: true, status: true } },
          },
        }),
        prisma.b2BAccount.count({ where }),
      ]);
      return apiResponse.paginated(res, data.map(a => ({
        ...a,
        availableCredit: Number(a.creditLimit) - Number(a.usedCredit),
        activeInvoices: a.b2bPayLaters.length,
        overdueAmount: a.b2bPayLaters.filter(p => p.status === 'OVERDUE').reduce((s, p) => s + Number(p.amount), 0),
      })), total, page, limit);
    } catch (err) { next(err); }
  }
);

// GET /b2b/admin/accounts/:id — account detail
router.get('/admin/accounts/:id', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  async (req, res, next) => {
    try {
      const account = await prisma.b2BAccount.findUnique({
        where: { id: req.params.id },
        include: {
          user: true,
          b2bPayLaters: { orderBy: { createdAt: 'desc' }, include: { request: true } },
          groupPayments: { orderBy: { createdAt: 'desc' } },
        },
      });
      if (!account) return apiResponse.error(res, 'Not found', 404);
      return apiResponse.success(res, { ...account, availableCredit: Number(account.creditLimit) - Number(account.usedCredit) });
    } catch (err) { next(err); }
  }
);

// PUT /b2b/admin/applications/:id/approve — approve B2B + set credit limit
router.put('/admin/applications/:id/approve', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  [body('creditLimit').isFloat({ min: 100 }).withMessage('حد ائتماني غير صحيح'),
   body('paymentTermDays').optional().isInt({ min: 1, max: 365 })],
  validate,
  async (req, res, next) => {
    try {
      const { creditLimit, paymentTermDays, notes } = req.body;
      const account = await prisma.b2BAccount.findUnique({
        where: { id: req.params.id }, include: { user: true },
      });
      if (!account) return apiResponse.error(res, 'Not found', 404);
      if (account.payLaterStatus !== 'PENDING_APPROVAL') return apiResponse.error(res, 'Already processed', 400);

      await prisma.b2BAccount.update({
        where: { id: account.id },
        data: {
          payLaterStatus: 'ACTIVE',
          creditLimit,
          paymentTermDays: paymentTermDays || 30,
          approvedAt: new Date(),
          approvedBy: req.admin.id,
        },
      });

      const io = req.app.get('io');
      await notifyUser(account.userId,
        '🎉 تم تفعيل حساب B2B الخاص بك',
        `تهانينا! تم الموافقة على طلبك. الحد الائتماني: ${creditLimit} ج.م`,
        'CRITICAL', { creditLimit: String(creditLimit) }
      );
      emitToAdmins(io, 'b2b_approved', { accountId: account.id, companyName: account.companyName });

      await prisma.auditLog.create({
        data: {
          adminId: req.admin.id, action: 'APPROVE_B2B',
          entity: 'b2b_account', entityId: account.id,
          details: `Credit limit: ${creditLimit}, Term: ${paymentTermDays || 30} days`,
        },
      });

      return apiResponse.success(res, null, 'تم الموافقة على طلب B2B');
    } catch (err) { next(err); }
  }
);

// PUT /b2b/admin/applications/:id/reject — reject B2B application
router.put('/admin/applications/:id/reject', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  [body('reason').notEmpty().withMessage('سبب الرفض مطلوب')],
  validate,
  async (req, res, next) => {
    try {
      const { reason } = req.body;
      const account = await prisma.b2BAccount.findUnique({ where: { id: req.params.id } });
      if (!account) return apiResponse.error(res, 'Not found', 404);

      await prisma.b2BAccount.update({
        where: { id: account.id },
        data: { payLaterStatus: 'REJECTED', rejectionReason: reason },
      });

      await notifyUser(account.userId, '❌ لم يتم قبول طلب B2B', `السبب: ${reason}`, 'HIGH');

      await prisma.auditLog.create({
        data: { adminId: req.admin.id, action: 'REJECT_B2B', entity: 'b2b_account', entityId: account.id, details: reason },
      });

      return apiResponse.success(res, null, 'تم رفض الطلب');
    } catch (err) { next(err); }
  }
);

// PUT /b2b/admin/accounts/:id/credit-limit — adjust credit limit
router.put('/admin/accounts/:id/credit-limit', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  [body('creditLimit').isFloat({ min: 0 })], validate,
  async (req, res, next) => {
    try {
      const { creditLimit, reason } = req.body;
      const account = await prisma.b2BAccount.findUnique({ where: { id: req.params.id } });
      if (!account) return apiResponse.error(res, 'Not found', 404);

      await prisma.b2BAccount.update({ where: { id: account.id }, data: { creditLimit } });
      await notifyUser(account.userId, '💳 تم تحديث الحد الائتماني', `الحد الجديد: ${creditLimit} ج.م`, 'HIGH');
      await prisma.auditLog.create({
        data: { adminId: req.admin.id, action: 'UPDATE_CREDIT_LIMIT', entity: 'b2b_account', entityId: account.id, details: `New limit: ${creditLimit}` },
      });

      return apiResponse.success(res, null, 'تم تحديث الحد الائتماني');
    } catch (err) { next(err); }
  }
);

// PUT /b2b/admin/accounts/:id/suspend — suspend B2B account
router.put('/admin/accounts/:id/suspend', authenticateAdmin, requireRole('SUPER_ADMIN'),
  async (req, res, next) => {
    try {
      const account = await prisma.b2BAccount.findUnique({ where: { id: req.params.id } });
      if (!account) return apiResponse.error(res, 'Not found', 404);
      await prisma.b2BAccount.update({ where: { id: account.id }, data: { payLaterStatus: 'SUSPENDED' } });
      await notifyUser(account.userId, '⚠️ تم تعليق حساب B2B', 'تم تعليق حساب Pay Later الخاص بك. تواصل مع الدعم.', 'CRITICAL');
      return apiResponse.success(res, null, 'تم تعليق الحساب');
    } catch (err) { next(err); }
  }
);

// GET /b2b/admin/pay-laters — all pay later invoices with filters
router.get('/admin/pay-laters', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  async (req, res, next) => {
    try {
      const { page, limit, skip } = paginate(req.query);
      const where = {};
      if (req.query.status) where.status = req.query.status;
      if (req.query.overdue === 'true') { where.dueDate = { lt: new Date() }; where.status = { not: 'SETTLED' }; }

      const [data, total] = await Promise.all([
        prisma.b2BPayLater.findMany({
          where, skip, take: limit, orderBy: { dueDate: 'asc' },
          include: { b2bAccount: { include: { user: { select: { phone: true, fullName: true } } } }, request: true },
        }),
        prisma.b2BPayLater.count({ where }),
      ]);
      return apiResponse.paginated(res, data, total, page, limit);
    } catch (err) { next(err); }
  }
);

// PUT /b2b/admin/pay-laters/:id/mark-settled — admin marks invoice settled
router.put('/admin/pay-laters/:id/mark-settled', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  async (req, res, next) => {
    try {
      const pl = await prisma.b2BPayLater.findUnique({ where: { id: req.params.id } });
      if (!pl) return apiResponse.error(res, 'Not found', 404);
      await prisma.$transaction([
        prisma.b2BPayLater.update({ where: { id: pl.id }, data: { status: 'SETTLED', settledAt: new Date() } }),
        prisma.b2BAccount.update({ where: { id: pl.b2bAccountId }, data: { usedCredit: { decrement: Number(pl.amount) } } }),
      ]);
      await prisma.auditLog.create({
        data: { adminId: req.admin.id, action: 'SETTLE_PAY_LATER', entity: 'b2b_pay_later', entityId: pl.id, details: pl.invoiceNo },
      });
      return apiResponse.success(res, null, 'تم تسجيل السداد');
    } catch (err) { next(err); }
  }
);

module.exports = router;
