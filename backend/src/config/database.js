'use strict';
const { PrismaClient } = require('@prisma/client');
const config = require('./env');

const prisma = new PrismaClient({
  log: config.isProd ? ['error'] : ['query','error','warn'],
});

module.exports = prisma;
