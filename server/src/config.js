import { DateTime } from 'luxon';

export const DEFAULT_WATER_TARGET = 8;
export const DEFAULT_AMOUNT_ML = 250;

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
    auth: {
      accessTokenSecret: env.ACCESS_TOKEN_SECRET || 'mock-development-secret-change-before-production',
      accessTokenTtlSeconds: Number(env.ACCESS_TOKEN_TTL_SECONDS || 30 * 60),
      refreshTokenTtlSeconds: Number(env.REFRESH_TOKEN_TTL_SECONDS || 30 * 24 * 60 * 60),
      bcryptRounds: Math.max(10, Number(env.BCRYPT_ROUNDS || 12)),
      loginFailureLimit: 5,
      loginLockSeconds: 15 * 60
    },
    db,
    dbConfigured: Boolean(db.host && db.name && db.user)
  };
}
