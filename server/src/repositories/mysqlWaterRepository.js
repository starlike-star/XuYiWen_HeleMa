export class MysqlWaterRepository {
  constructor(pool) {
    this.pool = pool;
  }

  async health() {
    try {
      await this.pool.query('SELECT 1');
      const [tables] = await this.pool.query(
        `SELECT table_name AS tableName
         FROM information_schema.tables
         WHERE table_schema = DATABASE()
           AND table_name IN ('users', 'user_sessions', 'water_records', 'user_daily_goals')`
      );
      if (tables.length !== 4) {
        return { status: 'unavailable', message: '数据库已连接，但表结构未初始化完整，请执行 server/sql/init.sql。' };
      }
      const [columns] = await this.pool.query(
        `SELECT table_name AS tableName, column_name AS columnName
         FROM information_schema.columns
         WHERE table_schema = DATABASE()
           AND (
             (table_name = 'users' AND column_name IN (
               'phone', 'password_hash', 'nickname', 'status', 'failed_login_count',
               'locked_until', 'last_login_at', 'created_at', 'updated_at'
             ))
             OR
             (table_name = 'user_sessions' AND column_name IN (
               'user_id', 'refresh_token_hash', 'expires_at', 'revoked_at'
             ))
           )`
      );
      const requiredColumns = [
        'users.phone', 'users.password_hash', 'users.nickname', 'users.status',
        'users.failed_login_count', 'users.locked_until', 'users.last_login_at',
        'users.created_at', 'users.updated_at', 'user_sessions.user_id',
        'user_sessions.refresh_token_hash', 'user_sessions.expires_at', 'user_sessions.revoked_at'
      ];
      const actualColumns = new Set(columns.map((column) => `${column.tableName}.${column.columnName}`));
      if (!requiredColumns.every((column) => actualColumns.has(column))) {
        return { status: 'unavailable', message: '数据库认证字段未初始化完整，请执行 server/sql/init.sql。' };
      }
      return { status: 'connected', message: '数据库连接正常。' };
    } catch (error) {
      if (error?.code === 'ER_NO_SUCH_TABLE') {
        return { status: 'unavailable', message: '数据库已连接，但表结构未初始化，请执行 server/sql/init.sql。' };
      }
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
    const scopedKey = `${userId}:${idempotencyKey}`;
    try {
      const [result] = await this.pool.execute(
        `INSERT INTO water_records (user_id, amount_ml, drank_at, idempotency_key)
         VALUES (?, ?, ?, ?)`,
        [userId, amountMl, drankAt, scopedKey]
      );
      return {
        created: true,
        record: { id: Number(result.insertId), userId, amountMl, drankAt, idempotencyKey: scopedKey }
      };
    } catch (error) {
      if (error && error.code === 'ER_DUP_ENTRY') {
        const [rows] = await this.pool.execute(
          `SELECT id, user_id AS userId, amount_ml AS amountMl, drank_at AS drankAt
           FROM water_records WHERE user_id = ? AND idempotency_key = ? LIMIT 1`,
          [userId, scopedKey]
        );
        return { created: false, record: rows[0] };
      }
      throw error;
    }
  }

  async getGoalsThroughDate(userId, date) {
    const [rows] = await this.pool.execute(
      `SELECT DATE_FORMAT(effective_date, '%Y-%m-%d') AS effectiveDate,
              target_count AS targetCount
       FROM user_daily_goals
       WHERE user_id = ? AND effective_date <= ?
       ORDER BY effective_date ASC`,
      [userId, date]
    );
    return rows.map((row) => ({ effectiveDate: row.effectiveDate, targetCount: Number(row.targetCount) }));
  }

  async updateDailyTarget(userId, effectiveDate, targetCount) {
    await this.pool.execute(
      `INSERT INTO user_daily_goals (user_id, effective_date, target_count)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE target_count = VALUES(target_count)`,
      [userId, effectiveDate, targetCount]
    );
  }

  async aggregateByLocalDate(userId, start, end, _timeZone, offset) {
    const [rows] = await this.pool.execute(
      `SELECT DATE_FORMAT(CONVERT_TZ(drank_at, '+00:00', ?), '%Y-%m-%d') AS date,
              COUNT(*) AS count
       FROM water_records
       WHERE user_id = ? AND drank_at >= ? AND drank_at < ?
       GROUP BY DATE_FORMAT(CONVERT_TZ(drank_at, '+00:00', ?), '%Y-%m-%d')
       ORDER BY date ASC`,
      [offset, userId, start, end, offset]
    );
    return rows.map((row) => ({ date: row.date, count: Number(row.count) }));
  }

  async aggregateAllByLocalDate(userId, end, _timeZone, offset) {
    const [rows] = await this.pool.execute(
      `SELECT DATE_FORMAT(CONVERT_TZ(drank_at, '+00:00', ?), '%Y-%m-%d') AS date,
              COUNT(*) AS count
       FROM water_records
       WHERE user_id = ? AND drank_at < ?
       GROUP BY DATE_FORMAT(CONVERT_TZ(drank_at, '+00:00', ?), '%Y-%m-%d')
       ORDER BY date ASC`,
      [offset, userId, end, offset]
    );
    return rows.map((row) => ({ date: row.date, count: Number(row.count) }));
  }

  async deleteById(userId, recordId) {
    const connection = await this.pool.getConnection();
    try {
      await connection.beginTransaction();
      const [rows] = await connection.execute(
        `SELECT id, user_id AS userId, amount_ml AS amountMl, drank_at AS drankAt,
                idempotency_key AS idempotencyKey
         FROM water_records WHERE user_id = ? AND id = ? FOR UPDATE`,
        [userId, recordId]
      );
      if (rows.length === 0) {
        await connection.rollback();
        return null;
      }
      await connection.execute('DELETE FROM water_records WHERE user_id = ? AND id = ?', [userId, recordId]);
      await connection.commit();
      return rows[0];
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  userColumns() {
    return `id, phone, password_hash AS passwordHash, nickname, status,
      failed_login_count AS failedLoginCount, locked_until AS lockedUntil,
      last_login_at AS lastLoginAt, created_at AS createdAt, updated_at AS updatedAt`;
  }

  async findUserByPhone(phone) {
    const [rows] = await this.pool.execute(
      `SELECT ${this.userColumns()} FROM users WHERE phone = ? LIMIT 1`, [phone]
    );
    return rows[0] || null;
  }

  async findUserById(userId) {
    const [rows] = await this.pool.execute(
      `SELECT ${this.userColumns()} FROM users WHERE id = ? LIMIT 1`, [userId]
    );
    return rows[0] || null;
  }

  async listUsers() {
    const [rows] = await this.pool.query(
      `SELECT id, phone, nickname, status, failed_login_count AS failedLoginCount,
              locked_until AS lockedUntil, last_login_at AS lastLoginAt,
              created_at AS createdAt, updated_at AS updatedAt
       FROM users WHERE phone IS NOT NULL ORDER BY id ASC`
    );
    return rows;
  }

  async createUser({ phone, passwordHash, nickname }) {
    const connection = await this.pool.getConnection();
    try {
      await connection.beginTransaction();
      const [result] = await connection.execute(
        `INSERT INTO users (phone, password_hash, nickname, status)
         VALUES (?, ?, ?, 'active')`,
        [phone, passwordHash, nickname]
      );
      const [rows] = await connection.execute(
        `SELECT ${this.userColumns()} FROM users WHERE id = ?`, [result.insertId]
      );
      await connection.commit();
      return rows[0];
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  async changePassword(phone, passwordHash, now) {
    const connection = await this.pool.getConnection();
    try {
      await connection.beginTransaction();
      const [users] = await connection.execute('SELECT id FROM users WHERE phone = ? FOR UPDATE', [phone]);
      if (users.length === 0) {
        await connection.rollback();
        return null;
      }
      const userId = users[0].id;
      await connection.execute(
        `UPDATE users SET password_hash = ?, failed_login_count = 0, locked_until = NULL,
                          updated_at = ? WHERE id = ?`,
        [passwordHash, now, userId]
      );
      await connection.execute(
        'UPDATE user_sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL',
        [now, userId]
      );
      await connection.commit();
      return this.findUserById(userId);
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  async setUserStatus(phone, status, now = new Date()) {
    const connection = await this.pool.getConnection();
    try {
      await connection.beginTransaction();
      const [users] = await connection.execute('SELECT id FROM users WHERE phone = ? FOR UPDATE', [phone]);
      if (users.length === 0) {
        await connection.rollback();
        return null;
      }
      const userId = users[0].id;
      await connection.execute('UPDATE users SET status = ?, updated_at = ? WHERE id = ?', [status, now, userId]);
      if (status !== 'active') {
        await connection.execute(
          'UPDATE user_sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL', [now, userId]
        );
      }
      await connection.commit();
      return this.findUserById(userId);
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  async recordLoginFailure(userId, lockedUntil) {
    await this.pool.execute(
      `UPDATE users SET failed_login_count = failed_login_count + 1,
                        locked_until = COALESCE(?, locked_until) WHERE id = ?`,
      [lockedUntil, userId]
    );
  }

  async recordLoginSuccess(userId, now) {
    await this.pool.execute(
      'UPDATE users SET failed_login_count = 0, locked_until = NULL, last_login_at = ? WHERE id = ?',
      [now, userId]
    );
  }

  async createSession(userId, expiresAt) {
    const [result] = await this.pool.execute(
      'INSERT INTO user_sessions (user_id, refresh_token_hash, expires_at) VALUES (?, ?, ?)',
      [userId, '', expiresAt]
    );
    return Number(result.insertId);
  }

  async setSessionTokenHash(sessionId, refreshTokenHash) {
    await this.pool.execute('UPDATE user_sessions SET refresh_token_hash = ? WHERE id = ?', [refreshTokenHash, sessionId]);
  }

  async findSessionById(sessionId) {
    const [rows] = await this.pool.execute(
      `SELECT id, user_id AS userId, refresh_token_hash AS refreshTokenHash,
              expires_at AS expiresAt, revoked_at AS revokedAt, created_at AS createdAt
       FROM user_sessions WHERE id = ? LIMIT 1`,
      [sessionId]
    );
    return rows[0] || null;
  }

  async revokeSession(sessionId, now) {
    await this.pool.execute(
      'UPDATE user_sessions SET revoked_at = COALESCE(revoked_at, ?) WHERE id = ?', [now, sessionId]
    );
  }

  async revokeAllSessions(userId, now) {
    await this.pool.execute(
      'UPDATE user_sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL', [now, userId]
    );
  }

  async migrateLegacyUserData(legacyUserId, targetPhone) {
    const connection = await this.pool.getConnection();
    try {
      await connection.beginTransaction();
      const [targets] = await connection.execute('SELECT id FROM users WHERE phone = ? FOR UPDATE', [targetPhone]);
      if (targets.length === 0) throw new Error('目标账号不存在');
      const targetUserId = Number(targets[0].id);
      if (targetUserId !== Number(legacyUserId)) {
        await connection.execute(
          `INSERT INTO user_daily_goals (user_id, effective_date, target_count, created_at, updated_at)
           SELECT ?, effective_date, target_count, created_at, updated_at
           FROM user_daily_goals WHERE user_id = ?
           ON DUPLICATE KEY UPDATE target_count = VALUES(target_count), updated_at = VALUES(updated_at)`,
          [targetUserId, legacyUserId]
        );
        await connection.execute('DELETE FROM user_daily_goals WHERE user_id = ?', [legacyUserId]);
        await connection.execute('UPDATE water_records SET user_id = ? WHERE user_id = ?', [targetUserId, legacyUserId]);
      }
      await connection.commit();
      return { legacyUserId: Number(legacyUserId), targetUserId };
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  async close() {
    await this.pool.end();
  }
}
