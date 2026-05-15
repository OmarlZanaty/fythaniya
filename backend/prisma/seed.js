'use strict';
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');
const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding فى ثانية v2 database...\n');

  // Super Admin
  const hash = await bcrypt.hash('Admin@123456', 12);
  await prisma.admin.upsert({
    where: { email: 'admin@fythaniya.com' },
    update: {},
    create: { email: 'admin@fythaniya.com', passwordHash: hash, fullName: 'Super Admin', role: 'SUPER_ADMIN' },
  });
  await prisma.admin.upsert({
    where: { email: 'processor@fythaniya.com' },
    update: {},
    create: { email: 'processor@fythaniya.com', passwordHash: hash, fullName: 'Transaction Processor', role: 'TRANSACTION_PROCESSOR' },
  });
  await prisma.admin.upsert({
    where: { email: 'b2b@fythaniya.com' },
    update: {},
    create: { email: 'b2b@fythaniya.com', passwordHash: hash, fullName: 'B2B Manager', role: 'B2B_MANAGER' },
  });
  console.log('✅ Admins seeded');

  // Service Providers
  const providers = [
    { name:'vodafone',    displayName:'فودافون مصر',         category:'TELECOM',     sortOrder:1, commissionRate:0.015 },
    { name:'orange',      displayName:'أورانج مصر',          category:'TELECOM',     sortOrder:2, commissionRate:0.015 },
    { name:'etisalat',    displayName:'إتصالات مصر',         category:'TELECOM',     sortOrder:3, commissionRate:0.015 },
    { name:'we_telecom',  displayName:'وي للاتصالات',        category:'TELECOM',     sortOrder:4, commissionRate:0.015 },
    { name:'cairo_elec',  displayName:'كهرباء القاهرة',      category:'ELECTRICITY', sortOrder:5, commissionRate:0.01  },
    { name:'alex_elec',   displayName:'كهرباء الإسكندرية',   category:'ELECTRICITY', sortOrder:6, commissionRate:0.01  },
    { name:'egypt_gas',   displayName:'الغاز المصري',        category:'GAS',         sortOrder:7, commissionRate:0.01  },
    { name:'cairo_water', displayName:'مياه القاهرة',        category:'WATER',       sortOrder:8, commissionRate:0.01  },
    { name:'we_internet', displayName:'وي للإنترنت',         category:'INTERNET',    sortOrder:9, commissionRate:0.02  },
    { name:'te_data',     displayName:'تي إي داتا',          category:'INTERNET',    sortOrder:10,commissionRate:0.02  },
    { name:'vodafone_cash',displayName:'فودافون كاش',         category:'TELECOM',     sortOrder:11,commissionRate:0.02  },
  ];

  const provMap = {};
  for (const p of providers) {
    const rec = await prisma.serviceProvider.upsert({
      where: { id: p.name },
      update: {},
      create: { id: p.name, ...p, isActive: true },
    });
    provMap[p.name] = rec.id;
    process.stdout.write(`  📡 ${p.displayName}\n`);
  }

  // Sub-Services
  const subServices = [
    // Vodafone
    { providerId:'vodafone', name:'Vodafone Recharge',  nameAr:'شحن فودافون',     category:'TELECOM',     min:5,  max:500,  fee:1.5, pct:0,    qa:[5,10,15,25,50,100] },
    { providerId:'vodafone', name:'Vodafone Data',      nameAr:'باقة إنترنت فودافون',category:'TELECOM',  min:10, max:300,  fee:2,   pct:0,    qa:[10,15,25,50,100,200] },
    { providerId:'vodafone', name:'Vodafone Bill',      nameAr:'فاتورة فودافون',  category:'TELECOM',     min:20, max:2000, fee:3,   pct:0,    qa:[] },
    // Orange
    { providerId:'orange',   name:'Orange Recharge',   nameAr:'شحن أورانج',      category:'TELECOM',     min:5,  max:500,  fee:1.5, pct:0,    qa:[5,10,15,25,50,100] },
    { providerId:'orange',   name:'Orange Data',       nameAr:'باقة إنترنت أورانج',category:'TELECOM',  min:10, max:300,  fee:2,   pct:0,    qa:[10,15,25,50,100,200] },
    { providerId:'orange',   name:'Orange Bill',       nameAr:'فاتورة أورانج',   category:'TELECOM',     min:20, max:2000, fee:3,   pct:0,    qa:[] },
    // Etisalat
    { providerId:'etisalat', name:'Etisalat Recharge', nameAr:'شحن إتصالات',     category:'TELECOM',     min:5,  max:500,  fee:1.5, pct:0,    qa:[5,10,15,25,50,100] },
    { providerId:'etisalat', name:'Etisalat Data',     nameAr:'باقة إنترنت إتصالات',category:'TELECOM', min:10, max:300,  fee:2,   pct:0,    qa:[10,25,50,100,200] },
    { providerId:'etisalat', name:'Etisalat Bill',     nameAr:'فاتورة إتصالات',  category:'TELECOM',     min:20, max:2000, fee:3,   pct:0,    qa:[] },
    // WE
    { providerId:'we_telecom',name:'WE Recharge',      nameAr:'شحن وي',          category:'TELECOM',     min:5,  max:500,  fee:1.5, pct:0,    qa:[5,10,15,25,50,100] },
    { providerId:'we_telecom',name:'WE Bill Mobile',   nameAr:'فاتورة وي موبايل',category:'TELECOM',     min:20, max:2000, fee:3,   pct:0,    qa:[] },
    // Electricity
    { providerId:'cairo_elec',name:'Cairo Electricity',nameAr:'كهرباء القاهرة',  category:'ELECTRICITY', min:20, max:5000, fee:3,   pct:0,    qa:[50,100,200,500,1000] },
    { providerId:'alex_elec', name:'Alex Electricity', nameAr:'كهرباء الإسكندرية',category:'ELECTRICITY',min:20, max:5000, fee:3,   pct:0,    qa:[50,100,200,500,1000] },
    // Gas
    { providerId:'egypt_gas', name:'Egypt Gas',        nameAr:'الغاز المصري',    category:'GAS',         min:10, max:2000, fee:2.5, pct:0,    qa:[50,100,200,500] },
    // Water
    { providerId:'cairo_water',name:'Cairo Water',     nameAr:'مياه القاهرة',    category:'WATER',       min:10, max:2000, fee:2,   pct:0,    qa:[50,100,200,500] },
    // Internet
    { providerId:'we_internet',name:'WE Internet Bill',nameAr:'فاتورة وي إنترنت',category:'INTERNET',    min:50, max:5000, fee:3,   pct:0,    qa:[100,200,500,1000] },
    { providerId:'we_internet',name:'WE Internet Data',nameAr:'باقة وي إنترنت',  category:'INTERNET',    min:59, max:2000, fee:2,   pct:0,    qa:[59,119,478,1852] },
    { providerId:'te_data',    name:'TE Data Bill',    nameAr:'فاتورة تي إي داتا',category:'INTERNET',   min:50, max:5000, fee:3,   pct:0,    qa:[100,200,500,1000] },
    // Vodafone Cash (requires Pay-Later activation)
    { providerId:'vodafone_cash', name:'Vodafone Cash Deposit', nameAr:'إيداع فودافون كاش', category:'TELECOM', min:50, max:5000, fee:0, pct:0.01, qa:[100,200,500,1000,2000], requiresPayLater:true },
  ];

  for (const s of subServices) {
    await prisma.subService.create({
      data: {
        serviceProviderId: s.providerId,
        name: s.name, nameAr: s.nameAr, category: s.category,
        minAmount: s.min, maxAmount: s.max,
        fixedFee: s.fee, percentageFee: s.pct,
        quickAmounts: JSON.stringify(s.qa),
        requiresPayLater: s.requiresPayLater || false,
        isActive: true, sortOrder: 0,
      },
    });
  }
  console.log(`✅ ${subServices.length} sub-services seeded`);

  // Vouchers
  const vouchers = [
    { code:'WELCOME10', discountPercent:10, maxUses:1000, pointsCost:0 },
    { code:'SILVER15',  discountPercent:15, maxUses:500,  pointsCost:200 },
    { code:'GOLD25',    discountPercent:25, maxUses:100,  pointsCost:500 },
    { code:'VIPFREE',   discountPercent:50, maxUses:10,   pointsCost:2000 },
  ];
  for (const v of vouchers) {
    await prisma.voucher.upsert({ where: { code: v.code }, update: {}, create: { ...v, isActive: true } });
  }
  console.log('✅ Vouchers seeded');

  // System Config
  const configs = [
    { key:'sla_standard_minutes', value: 15 },
    { key:'sla_critical_minutes', value: 5 },
    { key:'points_per_10_egp',    value: 1 },
    { key:'max_wallet_balance',   value: 50000 },
    { key:'maintenance_mode',     value: false },
    { key:'b2b_min_credit_limit', value: 1000 },
    { key:'b2b_max_credit_limit', value: 500000 },
  ];
  for (const c of configs) {
    await prisma.systemConfig.upsert({ where: { key: c.key }, update: { value: c.value }, create: { key: c.key, value: c.value } });
  }
  console.log('✅ Config seeded');

  console.log('\n🎉 Seed complete!\n');
  console.log('Admin credentials:');
  console.log('  SUPER_ADMIN:  admin@fythaniya.com / Admin@123456');
  console.log('  PROCESSOR:    processor@fythaniya.com / Admin@123456');
  console.log('  B2B_MANAGER:  b2b@fythaniya.com / Admin@123456');
}

main().catch(e => { console.error(e); process.exit(1); }).finally(() => prisma.$disconnect());
