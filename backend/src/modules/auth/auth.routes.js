'use strict';
const router = require('express').Router();
const { body } = require('express-validator');
const prisma = require('../../config/database');
const {
  jwtUtils, hashPassword, comparePassword, apiResponse,
  notifyUser, notifyAdmins, logger,
} = require('../../utils/all');
const { authLimiter, authenticateUser, authenticateAdmin, validate } = require('../../middleware/index');

const phoneRule = body('phone').trim().notEmpty().withMessage('رقم الهاتف مطلوب')
  .matches(/^[0-9+]{7,15}$/).withMessage('رقم الهاتف غير صحيح');

const passRule = body('password').isLength({ min: 6 })
  .withMessage('كلمة المرور يجب أن تكون 6 أحرف على الأقل');

// ─── REGISTER — no OTP, instant activation ───────────────────────────────────
router.post('/register', authLimiter,
  [body('fullName').trim().isLength({ min: 2 }).withMessage('الاسم مطلوب'), phoneRule, passRule],
  validate,
  async (req, res, next) => {
    try {
      const { phone, fullName, password } = req.body;
      const exists = await prisma.user.findUnique({ where: { phone: phone.trim() } });
      if (exists) return apiResponse.error(res, 'رقم الهاتف مسجل بالفعل', 409);

      const passwordHash = await hashPassword(password);
      const user = await prisma.user.create({
        data: {
          phone: phone.trim(), fullName: fullName.trim(),
          passwordHash, type: 'B2C',
          status: 'ACTIVE', kycVerified: true, kycVerifiedAt: new Date(),
        },
      });

      // Welcome bonus
      await prisma.$transaction([
        prisma.rewardTransaction.create({
          data: { userId: user.id, points: 50, isEarned: true, reason: 'مكافأة ترحيبية' },
        }),
        prisma.user.update({ where: { id: user.id }, data: { pointsBalance: { increment: 50 } } }),
      ]);

      const accessToken  = jwtUtils.signUser({ id: user.id, phone: user.phone, type: user.type });
      const refreshToken = jwtUtils.signRefresh({ id: user.id });

      await prisma.user.update({
        where: { id: user.id },
        data: { refreshToken, refreshTokenExp: new Date(Date.now() + 7 * 86400000), lastLoginAt: new Date() },
      });

      await notifyUser(user.id, '🎉 مرحباً بك في فى ثانية', 'تم إنشاء حسابك بنجاح. رصيدك 50 نقطة مكافأة!', 'HIGH');

      return apiResponse.success(res, {
        accessToken, refreshToken,
        user: {
          id: user.id, phone: user.phone, fullName: user.fullName,
          type: user.type, status: user.status,
          pointsBalance: 50, walletBalance: 0,
        },
      }, 'تم إنشاء الحساب بنجاح', 201);
    } catch (err) { next(err); }
  }
);

// ─── LOGIN ────────────────────────────────────────────────────────────────────
router.post('/login', authLimiter, [phoneRule, passRule], validate,
  async (req, res, next) => {
    try {
      const phone = req.body.phone.trim();
      const { password } = req.body;

      const user = await prisma.user.findUnique({ where: { phone } });
      if (!user) return apiResponse.error(res, 'بيانات الدخول غير صحيحة', 401);

      const valid = await comparePassword(password, user.passwordHash);
      if (!valid) return apiResponse.error(res, 'بيانات الدخول غير صحيحة', 401);

      if (user.status === 'SUSPENDED') return apiResponse.error(res, 'الحساب موقوف', 403);
      if (user.status === 'BANNED')    return apiResponse.error(res, 'الحساب محظور', 403);

      const accessToken  = jwtUtils.signUser({ id: user.id, phone: user.phone, type: user.type });
      const refreshToken = jwtUtils.signRefresh({ id: user.id });

      await prisma.user.update({
        where: { id: user.id },
        data: { refreshToken, refreshTokenExp: new Date(Date.now() + 7 * 86400000), lastLoginAt: new Date() },
      });

      return apiResponse.success(res, {
        accessToken, refreshToken,
        user: {
          id: user.id, phone: user.phone, fullName: user.fullName,
          email: user.email, type: user.type, status: user.status,
          pointsBalance: user.pointsBalance,
          walletBalance: Number(user.walletBalance),
        },
      }, 'تم تسجيل الدخول بنجاح');
    } catch (err) { next(err); }
  }
);

// ─── REFRESH TOKEN ────────────────────────────────────────────────────────────
router.post('/refresh-token', async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return apiResponse.error(res, 'Refresh token required', 400);
    const decoded = jwtUtils.verifyRefresh(refreshToken);
    const user = await prisma.user.findUnique({ where: { id: decoded.id } });
    if (!user || user.refreshToken !== refreshToken) return apiResponse.error(res, 'Invalid refresh token', 401);
    if (user.refreshTokenExp < new Date()) return apiResponse.error(res, 'Refresh token expired', 401);
    const newAccess  = jwtUtils.signUser({ id: user.id, phone: user.phone, type: user.type });
    const newRefresh = jwtUtils.signRefresh({ id: user.id });
    await prisma.user.update({ where: { id: user.id }, data: { refreshToken: newRefresh, refreshTokenExp: new Date(Date.now() + 7 * 86400000) } });
    return apiResponse.success(res, { accessToken: newAccess, refreshToken: newRefresh });
  } catch (err) { next(err); }
});

// ─── LOGOUT ───────────────────────────────────────────────────────────────────
router.post('/logout', authenticateUser, async (req, res, next) => {
  try {
    await prisma.user.update({
      where: { id: req.user.id },
      data: { refreshToken: null, refreshTokenExp: null },
    });
    return apiResponse.success(res, null, 'Logged out');
  } catch (err) { next(err); }
});

// ─── FORGOT PASSWORD ──────────────────────────────────────────────────────────
router.post('/forgot-password', authLimiter, [phoneRule], validate,
  async (req, res, next) => {
    try {
      const phone = req.body.phone.trim();
      const user = await prisma.user.findUnique({ where: { phone } });
      if (user) {
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        await prisma.systemConfig.upsert({
          where: { key: `reset_${phone}` },
          update: { value: { otp, exp: Date.now() + 600000 } },
          create: { key: `reset_${phone}`, value: { otp, exp: Date.now() + 600000 } },
        });
        logger.info(`[RESET OTP] ${phone} → ${otp}`);
        // TODO: send via SMS
      }
      return apiResponse.success(res, null, 'إذا كان الرقم مسجلاً، سيتم إرسال رمز التحقق');
    } catch (err) { next(err); }
  }
);

// ─── RESET PASSWORD ───────────────────────────────────────────────────────────
router.post('/reset-password', authLimiter,
  [phoneRule, body('otp').isLength({ min:6, max:6 }).isNumeric(), body('newPassword').isLength({ min:6 })],
  validate,
  async (req, res, next) => {
    try {
      const phone = req.body.phone.trim();
      const { otp, newPassword } = req.body;
      const rec = await prisma.systemConfig.findUnique({ where: { key: `reset_${phone}` } });
      if (!rec || rec.value.exp < Date.now()) return apiResponse.error(res, 'الرمز منتهي الصلاحية', 400);
      if (String(rec.value.otp) !== String(otp)) return apiResponse.error(res, 'الرمز غير صحيح', 400);
      await prisma.systemConfig.delete({ where: { key: `reset_${phone}` } });
      const hash = await hashPassword(newPassword);
      await prisma.user.update({ where: { phone }, data: { passwordHash: hash, refreshToken: null } });
      return apiResponse.success(res, null, 'تم تغيير كلمة المرور بنجاح');
    } catch (err) { next(err); }
  }
);

// ─── UPDATE DEVICE TOKEN (for push notifications) ─────────────────────────────
router.put('/device-token', authenticateUser, async (req, res, next) => {
  try {
    const { deviceToken } = req.body;
    if (!deviceToken) return apiResponse.error(res, 'deviceToken required', 400);
    await prisma.user.update({ where: { id: req.user.id }, data: { deviceToken } });
    return apiResponse.success(res, null, 'Device token updated');
  } catch (err) { next(err); }
});

// ─── ADMIN LOGIN ──────────────────────────────────────────────────────────────
router.post('/admin/login', authLimiter,
  [body('email').isEmail(), body('password').notEmpty()],
  validate,
  async (req, res, next) => {
    try {
      const { email, password } = req.body;
      const admin = await prisma.admin.findUnique({ where: { email } });
      if (!admin || !admin.isActive) return apiResponse.error(res, 'Invalid credentials', 401);
      const valid = await comparePassword(password, admin.passwordHash);
      if (!valid) return apiResponse.error(res, 'Invalid credentials', 401);
      const token = jwtUtils.signAdmin({ id: admin.id, email: admin.email, role: admin.role });
      await prisma.admin.update({ where: { id: admin.id }, data: { lastLoginAt: new Date() } });
      return apiResponse.success(res, {
        token,
        admin: { id: admin.id, email: admin.email, fullName: admin.fullName, role: admin.role },
      }, 'Admin login successful');
    } catch (err) { next(err); }
  }
);

// ─── ADMIN UPDATE DEVICE TOKEN ────────────────────────────────────────────────
router.put('/admin/device-token', authenticateAdmin, async (req, res, next) => {
  try {
    const { deviceToken } = req.body;
    if (!deviceToken) return apiResponse.error(res, 'deviceToken required', 400);
    await prisma.admin.update({ where: { id: req.admin.id }, data: { deviceToken } });
    return apiResponse.success(res, null, 'Device token updated');
  } catch (err) { next(err); }
});

module.exports = router;
