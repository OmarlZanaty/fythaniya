'use strict';
const path = require('path');
const fs = require('fs');
const multer = require('multer');

// Files live under /uploads/<kind>/<random>.<ext>
const UPLOAD_ROOT = process.env.UPLOAD_DIR || path.join(__dirname, '..', '..', 'uploads');

function ensureDir(dir) { if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true }); }

function makeUploader(kind, { maxMB = 5 } = {}) {
  ensureDir(path.join(UPLOAD_ROOT, kind));
  const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, path.join(UPLOAD_ROOT, kind)),
    filename: (req, file, cb) => {
      const ext = (path.extname(file.originalname) || '.jpg').toLowerCase().slice(0, 6);
      const rand = require('crypto').randomBytes(12).toString('hex');
      cb(null, `${Date.now()}_${rand}${ext}`);
    },
  });
  return multer({
    storage,
    limits: { fileSize: maxMB * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
      const ok = /^image\/(jpe?g|png|webp|gif)$/i.test(file.mimetype);
      cb(ok ? null : new Error('نوع ملف غير مدعوم — يجب أن يكون صورة'), ok);
    },
  });
}

// Public URL builder. Call after multer has placed the file.
function publicUrl(req, kind, filename) {
  const base = (process.env.PUBLIC_BASE_URL || `${req.protocol}://${req.get('host')}`).replace(/\/$/, '');
  return `${base}/uploads/${kind}/${filename}`;
}

module.exports = { makeUploader, publicUrl, UPLOAD_ROOT };
