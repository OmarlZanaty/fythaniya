module.exports = {
  apps: [{
    name: 'fythaniya-api',
    script: 'src/app.js',
    instances: 2,
    exec_mode: 'cluster',
    watch: false,
    max_memory_restart: '500M',
    restart_delay: 3000,
    max_restarts: 10,
    env_production: { NODE_ENV: 'production' },
    error_file: '/home/ubuntu/logs/fythaniya-error.log',
    out_file:   '/home/ubuntu/logs/fythaniya-out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
  }],
};
