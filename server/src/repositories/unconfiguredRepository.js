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

  async getGoalsThroughDate() {
    return this.unavailable();
  }

  async updateDailyTarget() {
    return this.unavailable();
  }

  async aggregateByLocalDate() {
    return this.unavailable();
  }

  async aggregateAllByLocalDate() {
    return this.unavailable();
  }

  async findUserByPhone() { return this.unavailable(); }
  async findUserById() { return this.unavailable(); }
  async listUsers() { return this.unavailable(); }
  async createUser() { return this.unavailable(); }
  async changePassword() { return this.unavailable(); }
  async setUserStatus() { return this.unavailable(); }
  async recordLoginFailure() { return this.unavailable(); }
  async recordLoginSuccess() { return this.unavailable(); }
  async createSession() { return this.unavailable(); }
  async setSessionTokenHash() { return this.unavailable(); }
  async findSessionById() { return this.unavailable(); }
  async revokeSession() { return this.unavailable(); }
  async revokeAllSessions() { return this.unavailable(); }

  unavailable() {
    throw new AppError(503, 'DB_NOT_CONFIGURED', '数据库连接尚未配置，请填写环境变量后重新启动服务。');
  }

  async close() {}
}
