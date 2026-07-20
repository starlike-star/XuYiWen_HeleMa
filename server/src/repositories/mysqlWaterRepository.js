export class MysqlWaterRepository {
  constructor(pool) {
    this.pool = pool;
  }

  async health() {
    try {
      await this.pool.query('SELECT 1');
      return { status: 'connected', message: '数据库连接正常。' };
    } catch {
      return { status: 'unavailable', message: '数据库暂时不可用。' };
    }
  }

  async listByRange(userId, start, end) {
    const [rows] = await this.pool.execute(
      `SELECT id, user_id AS userId, amount_ml AS amountMl, drank_at AS drankAt
       FROM water_records
       WHERE user_id = ? AND drank_at >= ? AND drank_at < ?
       ORDER BY drank_at ASC`,
      [userId, start, end]
    );
    return rows;
  }

  async create({ userId, amountMl, drankAt, idempotencyKey }) {
    try {
      const [result] = await this.pool.execute(
        `INSERT INTO water_records (user_id, amount_ml, drank_at, idempotency_key)
         VALUES (?, ?, ?, ?)`,
        [userId, amountMl, drankAt, idempotencyKey]
      );
      return {
        created: true,
        record: { id: Number(result.insertId), userId, amountMl, drankAt, idempotencyKey }
      };
    } catch (error) {
      if (error && error.code === 'ER_DUP_ENTRY') {
        const [rows] = await this.pool.execute(
          `SELECT id, user_id AS userId, amount_ml AS amountMl, drank_at AS drankAt
           FROM water_records WHERE idempotency_key = ? LIMIT 1`,
          [idempotencyKey]
        );
        return { created: false, record: rows[0] };
      }
      throw error;
    }
  }

  async deleteById(userId, recordId) {
    const [result] = await this.pool.execute(
      'DELETE FROM water_records WHERE user_id = ? AND id = ?',
      [userId, recordId]
    );
    return result.affectedRows > 0;
  }

  async close() {
    await this.pool.end();
  }
}
