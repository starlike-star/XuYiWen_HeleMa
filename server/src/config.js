import { DateTime } from 'luxon';

export const WATER_TARGET = 8;

export function loadConfig(env = process.env) {
  const dataMode = env.DATA_MODE || 'mock';
  if (dataMode !== 'mock' && dataMode !== 'mysql') {
    throw new Error('DATA_MODE 只能是 mock 或 mysql');
  }

  const timeZone = env.APP_TIME_ZONE || 'Asia/Shanghai';
  if (!DateTime.now().setZone(timeZone).isValid) {
    throw new Error(`无效的 APP_TIME_ZONE: ${timeZone}`);
  }

  const db = {
    host: env.DB_HOST || '',
    port: Number(env.DB_PORT || 3306),
    name: env.DB_NAME || '',
    user: env.DB_USER || '',
    password: env.DB_PASSWORD || ''
  };

  return {
    dataMode,
    serverPort: Number(env.SERVER_PORT || 3000),
    timeZone,
    defaultUserId: Number(env.DEFAULT_USER_ID || 1),
    db,
    dbConfigured: Boolean(db.host && db.name && db.user)
  };
}
