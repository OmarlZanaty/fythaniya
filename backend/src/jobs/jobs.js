'use strict';
const cron   = require('node-cron');
const prisma = require('../config/database');
const { logger, notifyUser, notifyAdmins, sendPush } = require('../utils/all');

// ─── JOB 1: SLA Escalation (every 2 min) ─────────────────────────────────────
async function runSLACheck(io) {
  try {
    const overdue = await prisma.request.findMany({
      where: { status: { in: ['PENDING','ASSIGNED','IN_PROGRESS'] }, slaDeadline: { lt: new Date() } },
      include: { user: true },
    });
    if (!overdue.length) return;
    logger.warn(`[SLA] ${overdue.length} requests breached SLA`);

    for (const r of overdue) {
      // Check if already escalated recently (last 10 min)
      const recentEscalation = await prisma.escalation.findFirst({
        where: { requestId: r.id, createdAt: { gt: new Date(Date.now() - 10 * 60000) } },
      });
      if (recentEscalation) continue;

      const level = r.type === 'B2B_PAY_LATER' ? 'LEVEL_1' : 'LEVEL_2';

      await prisma.escalation.create({
        data: { requestId: r.id, level, reason: 'SLA breach - auto escalation', escalatedBy: 'system' },
      });

      await notifyAdmins(
        `⚠️ تجاوز SLA — ${level}`,
        `الطلب #${r.id.slice(0,8)} تجاوز الوقت المحدد`,
        'CRITICAL', r.id,
        ['SUPER_ADMIN', 'TRANSACTION_PROCESSOR']
      );

      if (io) io.to('admin_room').emit('sla_breach', { requestId: r.id, level, userId: r.userId });
    }
  } catch (e) { logger.error('[SLA JOB]', e.message); }
}

// ─── JOB 2: B2B Overdue Check (daily 8am) ────────────────────────────────────
async function runB2BOverdueCheck() {
  try {
    const now = new Date();
    const overdue = await prisma.b2BPayLater.findMany({
      where: { status: 'ACTIVE', dueDate: { lt: now } },
      include: { b2bAccount: { include: { user: true } } },
    });
    if (!overdue.length) return;
    logger.info(`[B2B OVERDUE] ${overdue.length} invoices overdue`);

    for (const pl of overdue) {
      await prisma.b2BPayLater.update({ where: { id: pl.id }, data: { status: 'OVERDUE' } });
      await notifyUser(
        pl.b2bAccount.userId,
        '⚠️ فاتورة متأخرة السداد',
        `الفاتورة ${pl.invoiceNo} بمبلغ ${pl.amount} ج.م متأخرة. يرجى السداد فوراً.`,
        'CRITICAL', { invoiceNo: pl.invoiceNo, amount: String(pl.amount) }
      );
    }

    if (overdue.length > 0) {
      await notifyAdmins(
        `💰 ${overdue.length} فاتورة B2B متأخرة`,
        'يوجد فواتير B2B تجاوزت تاريخ الاستحقاق',
        'HIGH', null, ['SUPER_ADMIN','B2B_MANAGER']
      );
    }
  } catch (e) { logger.error('[B2B OVERDUE JOB]', e.message); }
}

// ─── JOB 3: Bill Reminders (daily 9am) ────────────────────────────────────────
async function runBillReminders() {
  try {
    const tomorrow = new Date(Date.now() + 86400000);
    const reminders = await prisma.billReminder.findMany({
      where: { isActive: true, dueDate: { gte: new Date(), lte: tomorrow } },
      include: { user: true },
    });
    if (!reminders.length) return;
    logger.info(`[BILL REMINDERS] ${reminders.length} reminders to send`);
    for (const r of reminders) {
      await notifyUser(r.userId, '🔔 تذكير بالفاتورة', `موعد سداد فاتورتك غداً — ${r.amount} ج.م`, 'HIGH');
    }
  } catch (e) { logger.error('[BILL REMINDER JOB]', e.message); }
}

// ─── JOB 4: Cleanup expired OTP configs (daily midnight) ─────────────────────
async function runCleanup() {
  try {
    const configs = await prisma.systemConfig.findMany({ where: { key: { startsWith: 'reset_' } } });
    let deleted = 0;
    for (const c of configs) {
      if (c.value?.exp && c.value.exp < Date.now()) {
        await prisma.systemConfig.delete({ where: { key: c.key } });
        deleted++;
      }
    }
    if (deleted) logger.info(`[CLEANUP] Deleted ${deleted} expired OTP configs`);
  } catch (e) { logger.error('[CLEANUP JOB]', e.message); }
}

module.exports.startJobs = (io) => {
  cron.schedule('*/2 * * * *',   () => runSLACheck(io),     { timezone: 'Africa/Cairo' });
  cron.schedule('0 8 * * *',     runB2BOverdueCheck,        { timezone: 'Africa/Cairo' });
  cron.schedule('0 9 * * *',     runBillReminders,          { timezone: 'Africa/Cairo' });
  cron.schedule('0 0 * * *',     runCleanup,                { timezone: 'Africa/Cairo' });
  logger.info('✅ All background jobs started');
};
