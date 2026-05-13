'use strict';
const router = require('express').Router();
const { body } = require('express-validator');
const prisma = require('../../config/database');
const { apiResponse, paginate, notifyUser, notifyAdmins, emitToAdmins, hashPassword } = require('../../utils/all');
const { authenticateUser, validate } = require('../../middleware/index');

// All routes require user auth
router.use(authenticateUser);

// ═══════════════════════════════════════════════════════════
//  PROFILE
// ═══════════════════════════════════════════════════════════

router.get('/profile', async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { id:true, phone:true, fullName:true, email:true, type:true, status:true, kycVerified:true, pointsBalance:true, walletBalance:true, createdAt:true, lastLoginAt:true },
    });
    return apiResponse.success(res, user);
  } catch (err) { next(err); }
});

router.put('/profile', [body('fullName').optional().isLength({ min: 2 }), body('email').optional().isEmail()], validate,
  async (req, res, next) => {
    try {
      const { fullName, email, deviceToken } = req.body;
      const data = {};
      if (fullName) data.fullName = fullName;
      if (deviceToken) data.deviceToken = deviceToken;
      if (email) {
        const taken = await prisma.user.findFirst({ where: { email, NOT: { id: req.user.id } } });
        if (taken) return apiResponse.error(res, 'البريد الإلكتروني مستخدم', 409);
        data.email = email;
      }
      const updated = await prisma.user.update({ where: { id: req.user.id }, data });
      return apiResponse.success(res, updated, 'تم التحديث');
    } catch (err) { next(err); }
  }
);

router.put('/change-password',
  [body('currentPassword').notEmpty(), body('newPassword').isLength({ min: 6 })],
  validate,
  async (req, res, next) => {
    try {
      const { comparePassword } = require('../../utils/all');
      const { currentPassword, newPassword } = req.body;
      const user = await prisma.user.findUnique({ where: { id: req.user.id } });
      const valid = await comparePassword(currentPassword, user.passwordHash);
      if (!valid) return apiResponse.error(res, 'كلمة المرور الحالية غير صحيحة', 400);
      const hash = await hashPassword(newPassword);
      await prisma.user.update({ where: { id: req.user.id }, data: { passwordHash: hash, refreshToken: null } });
      return apiResponse.success(res, null, 'تم تغيير كلمة المرور');
    } catch (err) { next(err); }
  }
);

// ═══════════════════════════════════════════════════════════
//  REQUESTS
// ═══════════════════════════════════════════════════════════

router.post('/requests',
  [
    body('serviceProviderId').notEmpty(),
    body('subServiceId').optional(),
    body('type').isIn(['MOBILE_RECHARGE','BILL_PAYMENT','INTERNET_RECHARGE','TRANSFER']),
    body('amount').isFloat({ min: 1 }),
    body('accountNumber').optional(),
    body('phoneNumber').optional(),
  ], validate,
  async (req, res, next) => {
    try {
      const { serviceProviderId, subServiceId, type, amount, accountNumber, phoneNumber } = req.body;
      const io = req.app.get('io');

      // Get fee from sub-service
      let fee = 0;
      if (subServiceId) {
        const sub = await prisma.subService.findUnique({ where: { id: subServiceId } });
        if (sub) fee = Number(sub.fixedFee) + (amount * Number(sub.percentageFee));
      }

      const totalAmount = amount + fee;
      const isCritical = ['MOBILE_RECHARGE'].includes(type);
      const slaMinutes = isCritical ? 5 : 15;
      const slaDeadline = new Date(Date.now() + slaMinutes * 60000);

      const request = await prisma.request.create({
        data: {
          userId: req.user.id, serviceProviderId,
          subServiceId: subServiceId || null,
          type, status: 'PENDING',
          amount, fee, totalAmount,
          accountNumber: accountNumber || null,
          phoneNumber: phoneNumber || null,
          slaDeadline,
        },
        include: { serviceProvider: true, subService: true },
      });

      await notifyAdmins(
        `🔔 طلب جديد — ${type}`,
        `${totalAmount} ج.م — ${accountNumber || phoneNumber || ''}`,
        isCritical ? 'CRITICAL' : 'HIGH',
        request.id,
        null,
        { requestId: request.id, type, amount: String(totalAmount) }
      );
      emitToAdmins(io, 'new_request', {
        requestId: request.id, type, amount: totalAmount,
        userId: req.user.id, slaDeadline,
      });

      return apiResponse.success(res, request, 'تم تقديم الطلب', 201);
    } catch (err) { next(err); }
  }
);

router.get('/requests', async (req, res, next) => {
  try {
    const { page, limit, skip } = paginate(req.query);
    const where = { userId: req.user.id };
    if (req.query.status) where.status = req.query.status;
    if (req.query.type)   where.type   = req.query.type;
    const [data, total] = await Promise.all([
      prisma.request.findMany({ where, skip, take: limit, orderBy: { createdAt: 'desc' }, include: { serviceProvider: true, subService: true } }),
      prisma.request.count({ where }),
    ]);
    return apiResponse.paginated(res, data, total, page, limit);
  } catch (err) { next(err); }
});

router.get('/requests/:id', async (req, res, next) => {
  try {
    const r = await prisma.request.findFirst({
      where: { id: req.params.id, userId: req.user.id },
      include: { serviceProvider: true, subService: true, transactions: true },
    });
    if (!r) return apiResponse.error(res, 'Not found', 404);
    return apiResponse.success(res, r);
  } catch (err) { next(err); }
});

// ═══════════════════════════════════════════════════════════
//  TRANSACTIONS
// ═══════════════════════════════════════════════════════════

router.get('/transactions', async (req, res, next) => {
  try {
    const { page, limit, skip } = paginate(req.query);
    const where = { userId: req.user.id };
    if (req.query.status) where.status = req.query.status;
    const [data, total] = await Promise.all([
      prisma.transaction.findMany({ where, skip, take: limit, orderBy: { createdAt: 'desc' }, include: { request: { include: { serviceProvider: true } } } }),
      prisma.transaction.count({ where }),
    ]);
    return apiResponse.paginated(res, data, total, page, limit);
  } catch (err) { next(err); }
});

// ═══════════════════════════════════════════════════════════
//  NOTIFICATIONS
// ═══════════════════════════════════════════════════════════

router.get('/notifications', async (req, res, next) => {
  try {
    const { page, limit, skip } = paginate(req.query);
    const where = { userId: req.user.id };
    if (req.query.isRead === 'false') where.isRead = false;
    if (req.query.isRead === 'true')  where.isRead = true;
    const [data, total, unreadCount] = await Promise.all([
      prisma.userNotification.findMany({ where, skip, take: limit, orderBy: { createdAt: 'desc' } }),
      prisma.userNotification.count({ where }),
      prisma.userNotification.count({ where: { userId: req.user.id, isRead: false } }),
    ]);
    return res.json({ success: true, data, pagination: { total, page: Number(req.query.page)||1, limit }, unreadCount });
  } catch (err) { next(err); }
});

router.put('/notifications/read-all', async (req, res, next) => {
  try {
    await prisma.userNotification.updateMany({ where: { userId: req.user.id, isRead: false }, data: { isRead: true } });
    return apiResponse.success(res, null, 'All read');
  } catch (err) { next(err); }
});

router.put('/notifications/:id/read', async (req, res, next) => {
  try {
    await prisma.userNotification.updateMany({ where: { id: req.params.id, userId: req.user.id }, data: { isRead: true } });
    return apiResponse.success(res, null, 'Read');
  } catch (err) { next(err); }
});

// ═══════════════════════════════════════════════════════════
//  REWARDS
// ═══════════════════════════════════════════════════════════

router.get('/rewards', async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({ where: { id: req.user.id }, select: { pointsBalance: true } });
    const history = await prisma.rewardTransaction.findMany({ where: { userId: req.user.id }, orderBy: { createdAt: 'desc' }, take: 30 });
    const pts = user.pointsBalance;
    const tier = pts >= 2000 ? 'Gold' : pts >= 500 ? 'Silver' : 'Bronze';
    return apiResponse.success(res, {
      pointsBalance: pts, tier,
      nextTierPoints: pts >= 2000 ? 0 : pts >= 500 ? 2000 - pts : 500 - pts,
      history,
    });
  } catch (err) { next(err); }
});

router.get('/vouchers', async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({ where: { id: req.user.id }, select: { pointsBalance: true } });
    const vouchers = await prisma.voucher.findMany({
      where: { isActive: true, OR: [{ validUntil: null }, { validUntil: { gt: new Date() } }] },
    });
    return apiResponse.success(res, vouchers.map(v => ({ ...v, canRedeem: user.pointsBalance >= v.pointsCost })));
  } catch (err) { next(err); }
});

router.post('/vouchers/redeem', [body('voucherId').notEmpty()], validate, async (req, res, next) => {
  try {
    const { voucherId } = req.body;
    const voucher = await prisma.voucher.findUnique({ where: { id: voucherId } });
    if (!voucher || !voucher.isActive) return apiResponse.error(res, 'القسيمة غير متاحة', 400);
    if (voucher.usedCount >= voucher.maxUses) return apiResponse.error(res, 'القسيمة نفدت', 400);
    const user = await prisma.user.findUnique({ where: { id: req.user.id }, select: { pointsBalance: true } });
    if (user.pointsBalance < voucher.pointsCost) return apiResponse.error(res, 'نقاط غير كافية', 400);
    await prisma.$transaction([
      prisma.voucher.update({ where: { id: voucherId }, data: { usedCount: { increment: 1 } } }),
      prisma.user.update({ where: { id: req.user.id }, data: { pointsBalance: { decrement: voucher.pointsCost } } }),
      prisma.rewardTransaction.create({ data: { userId: req.user.id, points: -voucher.pointsCost, isEarned: false, reason: 'استبدال قسيمة', referenceId: voucherId } }),
    ]);
    return apiResponse.success(res, { code: voucher.code, discountPercent: voucher.discountPercent });
  } catch (err) { next(err); }
});

// ═══════════════════════════════════════════════════════════
//  SPENDING
// ═══════════════════════════════════════════════════════════

router.get('/spending', async (req, res, next) => {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();
    const records = await prisma.spendingRecord.findMany({
      where: { userId: req.user.id, year },
      orderBy: { month: 'desc' },
    });
    return apiResponse.success(res, records);
  } catch (err) { next(err); }
});

// ═══════════════════════════════════════════════════════════
//  BILL REMINDERS
// ═══════════════════════════════════════════════════════════

router.get('/bill-reminders', async (req, res, next) => {
  try {
    const data = await prisma.billReminder.findMany({ where: { userId: req.user.id, isActive: true } });
    return apiResponse.success(res, data);
  } catch (err) { next(err); }
});

router.post('/bill-reminders',
  [body('providerId').notEmpty(), body('accountNumber').notEmpty(), body('amount').isFloat({ min: 1 }), body('dueDate').isISO8601()],
  validate,
  async (req, res, next) => {
    try {
      const { providerId, accountNumber, amount, dueDate, isRecurring, frequency } = req.body;
      const rec = await prisma.billReminder.create({
        data: { userId: req.user.id, providerId, accountNumber, amount, dueDate: new Date(dueDate), isRecurring: isRecurring || false, frequency },
      });
      return apiResponse.success(res, rec, 'تم إضافة التذكير', 201);
    } catch (err) { next(err); }
  }
);

router.delete('/bill-reminders/:id', async (req, res, next) => {
  try {
    await prisma.billReminder.updateMany({ where: { id: req.params.id, userId: req.user.id }, data: { isActive: false } });
    return apiResponse.success(res, null, 'تم الحذف');
  } catch (err) { next(err); }
});

module.exports = router;
