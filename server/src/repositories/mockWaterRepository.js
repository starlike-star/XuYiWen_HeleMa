export class MockWaterRepository {
  constructor() {
    this.records = [];
    this.nextId = 1;
    this.keys = new Map();
    this.goals = new Map();
    this.users = new Map();
    this.sessions = new Map();
    this.nextUserId = 1;
    this.nextSessionId = 1;
  }

  async health() {
    return { status: 'not_required', message: 'Mock 模式不需要数据库。' };
  }

  async listByRange(userId, start, end) {
    return this.records.filter((record) =>
      record.userId === userId && record.drankAt >= start && record.drankAt < end
    );
  }

  async create({ userId, amountMl, drankAt, idempotencyKey }) {
    const scopedKey = `${userId}:${idempotencyKey}`;
    const existing = this.keys.get(scopedKey);
    if (existing) {
      return { created: false, record: existing };
    }
    const record = { id: this.nextId++, userId, amountMl, drankAt, idempotencyKey };
    this.records.push(record);
    this.keys.set(scopedKey, record);
    return { created: true, record };
  }

  async getGoalsThroughDate(userId, date) {
    return Array.from(this.goals.values())
      .filter((goal) => goal.userId === userId && goal.effectiveDate <= date)
      .sort((left, right) => left.effectiveDate.localeCompare(right.effectiveDate));
  }

  async updateDailyTarget(userId, effectiveDate, targetCount) {
    const nextGoals = new Map(this.goals);
    nextGoals.set(`${userId}:${effectiveDate}`, { userId, effectiveDate, targetCount });
    this.goals = nextGoals;
  }

  async aggregateByLocalDate(userId, start, end, timeZone) {
    const { DateTime } = await import('luxon');
    const counts = new Map();
    for (const record of this.records) {
      if (record.userId !== userId || record.drankAt < start || record.drankAt >= end) continue;
      const date = DateTime.fromJSDate(record.drankAt, { zone: 'utc' }).setZone(timeZone).toISODate();
      counts.set(date, (counts.get(date) || 0) + 1);
    }
    return Array.from(counts, ([date, count]) => ({ date, count })).sort((a, b) => a.date.localeCompare(b.date));
  }

  async aggregateAllByLocalDate(userId, end, timeZone) {
    return this.aggregateByLocalDate(userId, new Date(0), end, timeZone);
  }

  async deleteById(userId, recordId) {
    const index = this.records.findIndex((item) => item.userId === userId && item.id === recordId);
    if (index < 0) return null;
    const [record] = this.records.splice(index, 1);
    this.keys.delete(`${userId}:${record.idempotencyKey}`);
    return record;
  }

  async close() {}

  async findUserByPhone(phone) {
    return Array.from(this.users.values()).find((user) => user.phone === phone) || null;
  }

  async findUserById(userId) {
    return this.users.get(userId) || null;
  }

  async createUser({ phone, passwordHash, nickname }) {
    if (await this.findUserByPhone(phone)) {
      const error = new Error('手机号已存在');
      error.code = 'ER_DUP_ENTRY';
      throw error;
    }
    const now = new Date();
    const user = {
      id: this.nextUserId++, phone, passwordHash, nickname, status: 'active',
      failedLoginCount: 0, lockedUntil: null, lastLoginAt: null, createdAt: now, updatedAt: now
    };
    this.users.set(user.id, user);
    return user;
  }

  async listUsers() {
    return Array.from(this.users.values());
  }

  async setUserStatus(phone, status, now = new Date()) {
    const user = await this.findUserByPhone(phone);
    if (!user) return null;
    user.status = status;
    user.updatedAt = now;
    if (status !== 'active') await this.revokeAllSessions(user.id, now);
    return user;
  }

  async changePassword(phone, passwordHash, now = new Date()) {
    const user = await this.findUserByPhone(phone);
    if (!user) return null;
    user.passwordHash = passwordHash;
    user.failedLoginCount = 0;
    user.lockedUntil = null;
    user.updatedAt = now;
    await this.revokeAllSessions(user.id, now);
    return user;
  }

  async recordLoginFailure(userId, lockedUntil) {
    const user = this.users.get(userId);
    if (!user) return;
    user.failedLoginCount += 1;
    user.lockedUntil = lockedUntil;
  }

  async recordLoginSuccess(userId, now) {
    const user = this.users.get(userId);
    user.failedLoginCount = 0;
    user.lockedUntil = null;
    user.lastLoginAt = now;
  }

  async createSession(userId, expiresAt) {
    const id = this.nextSessionId++;
    this.sessions.set(id, {
      id, userId, refreshTokenHash: null, expiresAt, revokedAt: null, createdAt: new Date()
    });
    return id;
  }

  async setSessionTokenHash(sessionId, refreshTokenHash) {
    this.sessions.get(sessionId).refreshTokenHash = refreshTokenHash;
  }

  async findSessionById(sessionId) {
    return this.sessions.get(sessionId) || null;
  }

  async revokeSession(sessionId, now) {
    const session = this.sessions.get(sessionId);
    if (session && !session.revokedAt) session.revokedAt = now;
  }

  async revokeAllSessions(userId, now) {
    for (const session of this.sessions.values()) {
      if (session.userId === userId && !session.revokedAt) session.revokedAt = now;
    }
  }

  async migrateLegacyUserData(legacyUserId, targetPhone) {
    const target = await this.findUserByPhone(targetPhone);
    if (!target) throw new Error('目标账号不存在');
    if (target.id !== legacyUserId) {
      for (const record of this.records) {
        if (record.userId === legacyUserId) record.userId = target.id;
      }
      const nextGoals = new Map();
      for (const goal of this.goals.values()) {
        const migrated = goal.userId === legacyUserId ? { ...goal, userId: target.id } : goal;
        nextGoals.set(`${migrated.userId}:${migrated.effectiveDate}`, migrated);
      }
      this.goals = nextGoals;
    }
    return { legacyUserId: Number(legacyUserId), targetUserId: target.id };
  }
}
