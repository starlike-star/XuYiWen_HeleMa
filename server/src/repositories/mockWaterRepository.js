export class MockWaterRepository {
  constructor() {
    this.records = [];
    this.nextId = 1;
    this.keys = new Map();
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
    const existing = this.keys.get(idempotencyKey);
    if (existing) {
      return { created: false, record: existing };
    }
    const record = { id: this.nextId++, userId, amountMl, drankAt, idempotencyKey };
    this.records.push(record);
    this.keys.set(idempotencyKey, record);
    return { created: true, record };
  }

  async deleteById(userId, recordId) {
    const index = this.records.findIndex((item) => item.userId === userId && item.id === recordId);
    if (index < 0) return false;
    const [record] = this.records.splice(index, 1);
    this.keys.delete(record.idempotencyKey);
    return true;
  }

  async close() {}
}
