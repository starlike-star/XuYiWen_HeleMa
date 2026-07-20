import mysql from 'mysql2/promise';
import { MockWaterRepository } from './mockWaterRepository.js';
import { MysqlWaterRepository } from './mysqlWaterRepository.js';
import { UnconfiguredRepository } from './unconfiguredRepository.js';

export function createRepository(config) {
  if (config.dataMode === 'mock') return new MockWaterRepository();
  if (!config.dbConfigured) return new UnconfiguredRepository();

  const pool = mysql.createPool({
    host: config.db.host,
    port: config.db.port,
    database: config.db.name,
    user: config.db.user,
    password: config.db.password,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    timezone: 'Z',
    dateStrings: false
  });
  return new MysqlWaterRepository(pool);
}
