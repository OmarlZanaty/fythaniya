'use strict';
const router = require('express').Router();
const { body } = require('express-validator');
const prisma = require('../../config/database');
const { apiResponse, paginate } = require('../../utils/all');
const { authenticateAdmin, requireRole, validate } = require('../../middleware/index');

// ─── PUBLIC ───────────────────────────────────────────────────────────────────

// GET /services/providers — all active providers with sub-services
router.get('/providers', async (req, res, next) => {
  try {
    const { category } = req.query;
    const where = { isActive: true };
    if (category) where.category = category;
    const providers = await prisma.serviceProvider.findMany({
      where,
      orderBy: { sortOrder: 'asc' },
      include: {
        subServices: {
          where: { isActive: true },
          orderBy: { sortOrder: 'asc' },
        },
      },
    });
    return apiResponse.success(res, providers);
  } catch (err) { next(err); }
});

// GET /services/providers/:id — single provider with all sub-services
router.get('/providers/:id', async (req, res, next) => {
  try {
    const provider = await prisma.serviceProvider.findUnique({
      where: { id: req.params.id },
      include: {
        subServices: { where: { isActive: true }, orderBy: { sortOrder: 'asc' } },
      },
    });
    if (!provider) return apiResponse.error(res, 'Provider not found', 404);
    return apiResponse.success(res, provider);
  } catch (err) { next(err); }
});

// GET /services/categories — grouped by category
router.get('/categories', async (req, res, next) => {
  try {
    const providers = await prisma.serviceProvider.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
      include: { subServices: { where: { isActive: true }, orderBy: { sortOrder: 'asc' } } },
    });
    const grouped = {};
    for (const p of providers) {
      if (!grouped[p.category]) grouped[p.category] = [];
      grouped[p.category].push(p);
    }
    return apiResponse.success(res, grouped);
  } catch (err) { next(err); }
});

// ─── ADMIN MANAGEMENT ─────────────────────────────────────────────────────────

// GET /services/admin/providers — all providers (including inactive)
router.get('/admin/providers', authenticateAdmin, async (req, res, next) => {
  try {
    const providers = await prisma.serviceProvider.findMany({
      orderBy: [{ category: 'asc' }, { sortOrder: 'asc' }],
      include: { subServices: { orderBy: { sortOrder: 'asc' } } },
    });
    return apiResponse.success(res, providers);
  } catch (err) { next(err); }
});

// POST /services/admin/providers — create provider
router.post('/admin/providers', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  [
    body('name').notEmpty(), body('displayName').notEmpty(),
    body('category').isIn(['TELECOM','ELECTRICITY','GAS','WATER','INTERNET','INSURANCE','GOVERNMENT']),
    body('commissionRate').optional().isFloat({ min: 0, max: 1 }),
  ], validate,
  async (req, res, next) => {
    try {
      const { name, displayName, category, logoUrl, sortOrder, commissionRate } = req.body;
      const provider = await prisma.serviceProvider.create({
        data: { name, displayName, category, logoUrl, sortOrder: sortOrder || 0, commissionRate: commissionRate || 0 },
      });
      return apiResponse.success(res, provider, 'Provider created', 201);
    } catch (err) { next(err); }
  }
);

// PUT /services/admin/providers/:id — update provider
router.put('/admin/providers/:id', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  async (req, res, next) => {
    try {
      const { name, displayName, category, logoUrl, sortOrder, isActive, commissionRate } = req.body;
      const provider = await prisma.serviceProvider.update({
        where: { id: req.params.id },
        data: {
          ...(name        !== undefined && { name }),
          ...(displayName !== undefined && { displayName }),
          ...(category    !== undefined && { category }),
          ...(logoUrl     !== undefined && { logoUrl }),
          ...(sortOrder   !== undefined && { sortOrder }),
          ...(isActive    !== undefined && { isActive }),
          ...(commissionRate !== undefined && { commissionRate }),
        },
        include: { subServices: true },
      });
      return apiResponse.success(res, provider, 'Provider updated');
    } catch (err) { next(err); }
  }
);

// DELETE /services/admin/providers/:id
router.delete('/admin/providers/:id', authenticateAdmin, requireRole('SUPER_ADMIN'),
  async (req, res, next) => {
    try {
      await prisma.serviceProvider.update({ where: { id: req.params.id }, data: { isActive: false } });
      return apiResponse.success(res, null, 'Provider deactivated');
    } catch (err) { next(err); }
  }
);

// ─── SUB-SERVICES ─────────────────────────────────────────────────────────────

// POST /services/admin/providers/:id/sub-services — create sub-service under provider
router.post('/admin/providers/:providerId/sub-services', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  [
    body('name').notEmpty(), body('nameAr').notEmpty(),
    body('category').isIn(['TELECOM','ELECTRICITY','GAS','WATER','INTERNET','INSURANCE','GOVERNMENT']),
    body('fixedFee').optional().isFloat({ min: 0 }),
    body('percentageFee').optional().isFloat({ min: 0, max: 1 }),
  ], validate,
  async (req, res, next) => {
    try {
      const { name, nameAr, description, category, minAmount, maxAmount, fixedFee, percentageFee, quickAmounts, sortOrder } = req.body;
      const sub = await prisma.subService.create({
        data: {
          serviceProviderId: req.params.providerId,
          name, nameAr, description, category,
          minAmount: minAmount || null, maxAmount: maxAmount || null,
          fixedFee: fixedFee || 0, percentageFee: percentageFee || 0,
          quickAmounts: quickAmounts ? JSON.stringify(quickAmounts) : null,
          sortOrder: sortOrder || 0,
        },
      });
      return apiResponse.success(res, sub, 'Sub-service created', 201);
    } catch (err) { next(err); }
  }
);

// PUT /services/admin/sub-services/:id — update sub-service
router.put('/admin/sub-services/:id', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  async (req, res, next) => {
    try {
      const { name, nameAr, description, minAmount, maxAmount, fixedFee, percentageFee, quickAmounts, sortOrder, isActive, requiresPayLater, imageUrl } = req.body;
      const sub = await prisma.subService.update({
        where: { id: req.params.id },
        data: {
          ...(name             !== undefined && { name }),
          ...(nameAr           !== undefined && { nameAr }),
          ...(description      !== undefined && { description }),
          ...(minAmount        !== undefined && { minAmount }),
          ...(maxAmount        !== undefined && { maxAmount }),
          ...(fixedFee         !== undefined && { fixedFee }),
          ...(percentageFee    !== undefined && { percentageFee }),
          ...(quickAmounts     !== undefined && { quickAmounts: JSON.stringify(quickAmounts) }),
          ...(sortOrder        !== undefined && { sortOrder }),
          ...(isActive         !== undefined && { isActive }),
          ...(requiresPayLater !== undefined && { requiresPayLater }),
          ...(imageUrl         !== undefined && { imageUrl }),
        },
      });
      return apiResponse.success(res, sub, 'Sub-service updated');
    } catch (err) { next(err); }
  }
);

// DELETE /services/admin/sub-services/:id
router.delete('/admin/sub-services/:id', authenticateAdmin, requireRole('SUPER_ADMIN'),
  async (req, res, next) => {
    try {
      await prisma.subService.update({ where: { id: req.params.id }, data: { isActive: false } });
      return apiResponse.success(res, null, 'Sub-service deactivated');
    } catch (err) { next(err); }
  }
);

// ─── IMAGE UPLOAD (provider logo / sub-service image) ────────────────────────
const { makeUploader, publicUrl } = require('../../middleware/upload');
const svcUploader = makeUploader('services', { maxMB: 3 });

router.post('/admin/providers/:id/logo', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  svcUploader.single('image'), async (req, res, next) => {
    try {
      if (!req.file) return apiResponse.error(res, 'لم يتم استلام صورة', 400);
      const url = publicUrl(req, 'services', req.file.filename);
      const p = await prisma.serviceProvider.update({ where: { id: req.params.id }, data: { logoUrl: url } });
      return apiResponse.success(res, { logoUrl: url, provider: p }, 'تم رفع الشعار');
    } catch (err) { next(err); }
  }
);

router.post('/admin/sub-services/:id/image', authenticateAdmin, requireRole('SUPER_ADMIN', 'B2B_MANAGER'),
  svcUploader.single('image'), async (req, res, next) => {
    try {
      if (!req.file) return apiResponse.error(res, 'لم يتم استلام صورة', 400);
      const url = publicUrl(req, 'services', req.file.filename);
      const s = await prisma.subService.update({ where: { id: req.params.id }, data: { imageUrl: url } });
      return apiResponse.success(res, { imageUrl: url, subService: s }, 'تم رفع الصورة');
    } catch (err) { next(err); }
  }
);

module.exports = router;
