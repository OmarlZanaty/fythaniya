'use strict';
const router = require('express').Router();
const { body } = require('express-validator');
const prisma = require('../config/database');
const { apiResponse, paginate, notifyUser, notifyAdmins, emitToAdmins, hashPassword } = require('../utils/all');
const { authenticateUser, validate } = require('../middleware/index');

// All routes require user auth
router.use(authenticateUser);

// ═══════════════════════════════════════════════════════════
//  PROFILE
// ═══════════════════════════════════════════════════════════

router.get('/profile', async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { id:true, phone:true, fullName:true, email:true, type:true, status:true, kycVerified:true,
        pointsBalance:true, walletBalance:true, payLaterEligible:true, payLaterApprovedAt:true,
        createdAt:true, lastLoginAt:true },
    });
    // Has the user already requested pay-later activation? (so the UI can show "pending")
    const pendingActivation = !user.payLaterEligible ? await prisma.request.findFirst({
      where: { userId: req.user.id, type: 'PAY_LATER_ACTIVATION', status: { in: ['PENDING','ASSIGNED','IN_PROGRESS'] } },
      select: { id: true, status: true, createdAt: true },
    }) : null;
    return apiResponse.success(res, { ...user, payLaterPending: !!pendingActivation, payLaterPendingRequestId: pendingActivation?.id ?? null });
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
      const updated = await prisma.user.update({
        where: { id: req.user.id }, data,
        select: { id:true, phone:true, fullName:true, email:true, type:true, status:true, kycVerified:true, pointsBalance:true, walletBalance:true, createdAt:true, lastLoginAt:true },
      });
      return apiResponse.success(res, updated, 'تم التحديث');
    } catch (err) { next(err); }
  }
);

router.put('/change-password',
  [body('currentPassword').notEmpty(), body('newPassword').isLength({ min: 6 })],
  validate,
  async (req, res, next) => {
    try {
      const { comparePassword } = require('../utils/all');
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
    body('type').isIn(['MOBILE_RECHARGE','BILL_PAYMENT','INTERNET_RECHARGE','TRANSFER','VODAFONE_CASH_DEPOSIT']),
    body('amount').isFloat({ min: 1, max: 50000 }).withMessage('المبلغ يجب أن يكون بين 1 و 50000 ج.م'),
    body('accountNumber').optional(),
    body('phoneNumber').optional(),
    body('paymentMethod').optional().isString(),
    body('proofImageUrl').optional().isString(),
  ], validate,
  async (req, res, next) => {
    try {
      const { serviceProviderId, subServiceId, type, amount, accountNumber, phoneNumber, paymentMethod, proofImageUrl } = req.body;
      const io = req.app.get('io');

      // Sub-service gating + fee
      let fee = 0;
      if (subServiceId) {
        const sub = await prisma.subService.findUnique({ where: { id: subServiceId } });
        if (!sub) return apiResponse.error(res, 'الخدمة الفرعية غير موجودة', 404);
        if (sub.requiresPayLater) {
          const me = await prisma.user.findUnique({ where: { id: req.user.id }, select: { payLaterEligible: true } });
          if (!me?.payLaterEligible) return apiResponse.error(res, 'هذه الخدمة غير متاحة لحسابك. يرجى تفعيل الدفع الآجل أولاً.', 403);
        }
        fee = Number(sub.fixedFee) + (Number(amount) * Number(sub.percentageFee));
      }

      const totalAmount = Number(amount) + fee;
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
          paymentMethod: paymentMethod || null,
          proofImageUrl: proofImageUrl || null,
          slaDeadline,
        },
        include: { serviceProvider: true, subService: true },
      });

      await notifyAdmins(
        `🔔 طلب جديد — ${type}`,
        `${totalAmount} ج.م — ${accountNumber || phoneNumber || ''}`,
        isCritical ? 'CRITICAL' : 'HIGH',
        request.id, null,
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
      prisma.transaction.findMany({
        where, skip, take: limit, orderBy: { createdAt: 'desc' },
        include: {
          request: {
            select: {
              id: true, type: true, status: true, amount: true, fee: true, totalAmount: true,
              accountNumber: true, phoneNumber: true, createdAt: true,
              serviceProvider: { select: { id: true, name: true, displayName: true, category: true } },
              subService: { select: { id: true, name: true, nameAr: true, category: true, serviceProviderId: true } },
            },
          },
        },
      }),
      prisma.transaction.count({ where }),
    ]);
    return apiResponse.paginated(res, data, total, page, limit);
  } catch (err) { next(err); }
});

// ═══════════════════════════════════════════════════════════
//  WALLET (top-up & transfer)
// ═══════════════════════════════════════════════════════════

// Wallet top-up is now a REQUEST that an admin must approve after verifying
// the payment proof the user uploads. The wallet is credited only on approval.
router.post('/wallet/topup',
  [
    body('amount').isFloat({ min: 10, max: 10000 }).withMessage('المبلغ يجب أن يكون بين 10 و 10000 ج.م'),
    body('paymentMethod').optional().isString(),
  ],
  validate,
  async (req, res, next) => {
    try {
      const amount = Number(req.body.amount);
      const paymentMethod = (req.body.paymentMethod || 'BANK_TRANSFER').toString();
      const slaDeadline = new Date(Date.now() + 60 * 60000); // 1h to verify

      const request = await prisma.request.create({
        data: {
          userId: req.user.id,
          type: 'WALLET_TOPUP', status: 'PENDING',
          amount, fee: 0, totalAmount: amount,
          paymentMethod, slaDeadline,
        },
      });

      const io = req.app.get('io');
      emitToAdmins(io, 'new_request', { requestId: request.id, type: 'WALLET_TOPUP', amount: String(amount), userId: req.user.id, slaDeadline });
      await notifyAdmins(`🔔 طلب شحن محفظة جديد`, `${amount} ج.م — بانتظار التحقق`, 'HIGH', request.id, null, { requestId: request.id, type: 'WALLET_TOPUP' });
      await notifyUser(req.user.id, '⏳ تم استلام طلب الشحن', `طلب شحن محفظتك بمبلغ ${amount} ج.م قيد المراجعة. سيتم إضافة المبلغ بعد التحقق من إثبات الدفع.`, 'NORMAL', { requestId: request.id });

      return apiResponse.success(res, { requestId: request.id, amount, status: 'PENDING' }, 'تم إرسال طلب الشحن للمراجعة', 201);
    } catch (err) { next(err); }
  }
);

// Pay-later activation request — admin must approve before user can use pay-later
router.post('/pay-later/activate', async (req, res, next) => {
  try {
    const me = await prisma.user.findUnique({ where: { id: req.user.id }, select: { payLaterEligible: true, fullName: true } });
    if (me.payLaterEligible) return apiResponse.error(res, 'تم تفعيل خدمة الدفع الآجل لحسابك بالفعل', 400);

    const existing = await prisma.request.findFirst({
      where: { userId: req.user.id, type: 'PAY_LATER_ACTIVATION', status: { in: ['PENDING','ASSIGNED','IN_PROGRESS'] } },
    });
    if (existing) return apiResponse.error(res, 'لديك طلب تفعيل قيد المراجعة بالفعل', 409);

    const request = await prisma.request.create({
      data: { userId: req.user.id, type: 'PAY_LATER_ACTIVATION', status: 'PENDING', amount: 0, fee: 0, totalAmount: 0 },
    });

    const io = req.app.get('io');
    emitToAdmins(io, 'new_request', { requestId: request.id, type: 'PAY_LATER_ACTIVATION', amount: '0', userId: req.user.id });
    await notifyAdmins(`📝 طلب تفعيل الدفع الآجل`, `${me.fullName} يطلب تفعيل خدمة الدفع الآجل`, 'HIGH', request.id);

    return apiResponse.success(res, { requestId: request.id, status: 'PENDING' }, 'تم إرسال طلب التفعيل للمراجعة', 201);
  } catch (err) { next(err); }
});

// Upload payment-proof image for a request. Must be the request owner.
const { makeUploader, publicUrl } = require('../middleware/upload');
const proofUploader = makeUploader('proofs', { maxMB: 5 });
router.post('/requests/:id/proof', proofUploader.single('image'), async (req, res, next) => {
  try {
    if (!req.file) return apiResponse.error(res, 'لم يتم استلام صورة', 400);
    const r = await prisma.request.findFirst({ where: { id: req.params.id, userId: req.user.id } });
    if (!r) return apiResponse.error(res, 'Not found', 404);
    if (!['PENDING','ASSIGNED','IN_PROGRESS'].includes(r.status)) return apiResponse.error(res, 'لا يمكن رفع إثبات بعد إنهاء الطلب', 400);

    const url = publicUrl(req, 'proofs', req.file.filename);
    await prisma.request.update({ where: { id: r.id }, data: { proofImageUrl: url } });
    return apiResponse.success(res, { proofImageUrl: url }, 'تم رفع الإثبات');
  } catch (err) { next(err); }
});

router.post('/wallet/transfer',
  [
    body('toPhone').trim().matches(/^[0-9+]{7,15}$/).withMessage('رقم هاتف المستلم غير صحيح'),
    body('amount').isFloat({ min: 5, max: 50000 }).withMessage('المبلغ يجب أن يكون بين 5 و 50000 ج.م'),
    body('note').optional().isLength({ max: 200 }),
  ],
  validate,
  async (req, res, next) => {
    try {
      const { toPhone, note } = req.body;
      const amount = Number(req.body.amount);
      const toPhoneTrim = toPhone.trim();

      const senderPhone = (await prisma.user.findUnique({ where: { id: req.user.id }, select: { phone: true } }))?.phone;
      if (senderPhone === toPhoneTrim) return apiResponse.error(res, 'لا يمكنك التحويل إلى نفسك', 400);

      const recipient = await prisma.user.findUnique({ where: { phone: toPhoneTrim }, select: { id: true, phone: true, fullName: true, status: true } });
      if (!recipient) return apiResponse.error(res, 'المستلم غير موجود', 404);
      if (recipient.status !== 'ACTIVE') return apiResponse.error(res, 'حساب المستلم غير نشط', 400);

      // Atomic transfer with balance guard via conditional update (returns count=0 if insufficient).
      let result;
      try {
        result = await prisma.$transaction(async (tx) => {
          const dec = await tx.user.updateMany({
            where: { id: req.user.id, walletBalance: { gte: amount } },
            data: { walletBalance: { decrement: amount } },
          });
          if (dec.count === 0) throw new Error('INSUFFICIENT_BALANCE');
          await tx.user.update({ where: { id: recipient.id }, data: { walletBalance: { increment: amount } } });
          const senderTxn = await tx.transaction.create({
            data: { userId: req.user.id, amount, fee: 0, totalAmount: amount, status: 'SUCCESS', paymentMethod: 'TRANSFER_OUT', externalRef: recipient.phone },
          });
          await tx.transaction.create({
            data: { userId: recipient.id, amount, fee: 0, totalAmount: amount, status: 'SUCCESS', paymentMethod: 'TRANSFER_IN', externalRef: senderPhone },
          });
          const updatedSender = await tx.user.findUnique({ where: { id: req.user.id }, select: { walletBalance: true, fullName: true } });
          return { newBalance: updatedSender.walletBalance, transactionId: senderTxn.id, recipientName: recipient.fullName, senderName: updatedSender.fullName };
        });
      } catch (e) {
        if (e.message === 'INSUFFICIENT_BALANCE') return apiResponse.error(res, 'الرصيد غير كافٍ', 400);
        throw e;
      }

      await notifyUser(req.user.id, '💸 تم التحويل', `تم تحويل ${amount} ج.م إلى ${recipient.fullName}`, 'NORMAL');
      await notifyUser(recipient.id, '💰 تحويل وارد', `استلمت ${amount} ج.م من ${result.senderName}${note ? ' — ' + note : ''}`, 'NORMAL');

      return apiResponse.success(res, { newBalance: result.newBalance, transactionId: result.transactionId, recipientName: result.recipientName }, 'تم التحويل بنجاح', 201);
    } catch (err) { next(err); }
  }
);

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

    try {
      await prisma.$transaction(async (tx) => {
        // Atomic increment of usedCount, only if still under maxUses (prevents over-redemption race).
        const vUpd = await tx.voucher.updateMany({
          where: { id: voucherId, isActive: true, usedCount: { lt: voucher.maxUses } },
          data: { usedCount: { increment: 1 } },
        });
        if (vUpd.count === 0) throw new Error('VOUCHER_DEPLETED');
        // Atomic decrement of points, only if user still has enough.
        const uUpd = await tx.user.updateMany({
          where: { id: req.user.id, pointsBalance: { gte: voucher.pointsCost } },
          data: { pointsBalance: { decrement: voucher.pointsCost } },
        });
        if (uUpd.count === 0) throw new Error('INSUFFICIENT_POINTS');
        await tx.rewardTransaction.create({
          data: { userId: req.user.id, points: -voucher.pointsCost, isEarned: false, reason: 'استبدال قسيمة', referenceId: voucherId },
        });
      });
    } catch (e) {
      if (e.message === 'VOUCHER_DEPLETED') return apiResponse.error(res, 'القسيمة نفدت', 400);
      if (e.message === 'INSUFFICIENT_POINTS') return apiResponse.error(res, 'نقاط غير كافية', 400);
      throw e;
    }
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
