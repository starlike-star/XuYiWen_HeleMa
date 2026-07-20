import { AppError } from '../errors.js';

export class UnconfiguredRepository {
  async health() {
    return { status: 'not_configured', message: '数据库连接尚未配置。' };
  }

  async listByRange() {
    throw new AppError(503, 'DB_NOT_CONFIGURED', '数据库连接尚未配置，请填写环境变量后重新启动服务。');
  }

  async create() {
    throw new AppError(503, 'DB_NOT_CONFIGURED', '数据库连接尚未配置，请填写环境变量后重新启动服务。');
  }

  async deleteById() {
    throw new AppError(503, 'DB_NOT_CONFIGURED', '数据库连接尚未配置，请填写环境变量后重新启动服务。');
  }

  async close() {}
}
