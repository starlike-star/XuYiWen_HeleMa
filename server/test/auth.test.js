import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createApp } from '../src/app.js';
import { AuthService } from '../src/auth/authService.js';
import { hashPassword, verifyPassword } from '../src/auth/password.js';
import { isValidPassword, normalizePhone } from '../src/auth/validation.js';
import { MockWaterRepository } from '../src/repositories/mockWaterRepository.js';
import { WaterService } from '../src/waterService.js';

const authConfig = {
  accessTokenSecret: 'auth-test-secret', accessTokenTtlSeconds: 1800,
  refreshTokenTtlSeconds: 2592000, bcryptRounds: 10,
  loginFailureLimit: 5, loginLockSeconds: 900
};
const waterConfig = { dataMode: 'mock', timeZone: 'Asia/Shanghai', auth: authConfig };

test('手机号与密码规则符合第一版约束且密码不自动 trim', () => {
  assert.equal(normalizePhone('13800000000'), '+8613800000000');
  for (const phone of ['', '12800000000', '1380000000', '138000000000', '1380000000a']) {
    assert.equal(normalizePhone(phone), null);
  }
  assert.equal(isValidPassword('Password1'), true);
  assert.equal(isValidPassword(' Password1'), true);
  assert.equal(isValidPassword('12345678'), false);
  assert.equal(isValidPassword('abcdefgh'), false);
  assert.equal(isValidPassword('Pass1'), false);
});

test('bcrypt 工作因子不低于 10 且可验证密码', async () => {
  const hash = await hashPassword('Password1!', 10);
  assert.match(hash, /^\$2[aby]\$10\$/);
  assert.equal(await verifyPassword('Password1!', hash), true);
  assert.equal(await verifyPassword('Password2!', hash), false);
});

test('登录成功、统一失败提示、五次失败锁定与成功清零', async () => {
  const repository = new MockWaterRepository();
  let now = new Date('2026-07-23T00:00:00Z');
  const auth = new AuthService(repository, authConfig, () => new Date(now));
  const user = await auth.createAccount('13800000000', 'Password1!', '用户甲');
  const successful = await auth.login('13800000000', 'Password1!');
  assert.equal(successful.user.id, user.id);
  assert.ok(successful.accessToken);
  for (let index = 0; index < 5; index += 1) {
    await assert.rejects(auth.login('13800000000', 'WrongPass1!'), (error) =>
      error.code === 'INVALID_CREDENTIALS' && error.message === '手机号或密码不正确'
    );
  }
  await assert.rejects(auth.login('13800000000', 'Password1!'), (error) => error.code === 'ACCOUNT_LOCKED');
  now = new Date(now.getTime() + 16 * 60 * 1000);
  await auth.login('13800000000', 'Password1!');
  assert.equal((await repository.findUserById(user.id)).failedLoginCount, 0);
  await assert.rejects(auth.login('13900000000', 'WrongPass1!'), (error) =>
    error.code === 'INVALID_CREDENTIALS' && error.message === '手机号或密码不正确'
  );
});

test('Refresh Token 轮换、退出撤销和停用账号撤销全部会话', async () => {
  const repository = new MockWaterRepository();
  const auth = new AuthService(repository, authConfig);
  await auth.createAccount('13800000000', 'Password1!', '用户甲');
  const first = await auth.login('13800000000', 'Password1!');
  const refreshed = await auth.refresh(first.refreshToken);
  assert.ok(refreshed.accessToken);
  await assert.rejects(auth.refresh(first.refreshToken), (error) => error.code === 'REFRESH_TOKEN_INVALID');
  const claims = await auth.authenticate(refreshed.accessToken);
  await auth.logout(claims.sessionId);
  await assert.rejects(auth.authenticate(refreshed.accessToken), (error) => error.code === 'AUTHENTICATION_REQUIRED');
  const active = await auth.login('13800000000', 'Password1!');
  await repository.setUserStatus('+8613800000000', 'disabled');
  await assert.rejects(auth.authenticate(active.accessToken), (error) => error.code === 'AUTHENTICATION_REQUIRED');
});

test('API 按 Token 隔离数据且跨用户删除返回不存在', async () => {
  const repository = new MockWaterRepository();
  const auth = new AuthService(repository, authConfig);
  const service = new WaterService(repository, waterConfig, () => new Date('2026-07-23T01:00:00Z'));
  await auth.createAccount('13800000000', 'Password1!', '用户甲');
  await auth.createAccount('13900000000', 'Password2!', '用户乙');
  const a = await auth.login('13800000000', 'Password1!');
  const b = await auth.login('13900000000', 'Password2!');
  const app = createApp(service, auth);
  const server = await new Promise((resolve) => {
    const instance = app.listen(0, '127.0.0.1', () => resolve(instance));
  });
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const call = async (path, token, options = {}) => {
    const response = await fetch(`${baseUrl}${path}`, {
      ...options, headers: { ...(options.headers || {}), Authorization: `Bearer ${token}` }
    });
    return { response, body: await response.json() };
  };
  try {
    const checked = await call('/api/water/check-in', a.accessToken, {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'Idempotency-Key': 'shared-key' }, body: '{}'
    });
    const otherToday = await call('/api/water/today', b.accessToken);
    assert.equal(otherToday.body.data.count, 0);
    const denied = await call(`/api/water/records/${checked.body.data.recordId}`, b.accessToken, { method: 'DELETE' });
    assert.equal(denied.response.status, 404);
    assert.equal(denied.body.error.code, 'RECORD_NOT_FOUND');
    const ownerToday = await call('/api/water/today', a.accessToken);
    assert.equal(ownerToday.body.data.count, 1);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('默认用户数据迁移重复执行保持同一归属', async () => {
  const repository = new MockWaterRepository();
  const legacy = await repository.createUser({
    phone: '+8613700000000', passwordHash: 'legacy', nickname: '旧用户'
  });
  const target = await repository.createUser({
    phone: '+8613800000000', passwordHash: 'target', nickname: '目标用户'
  });
  await repository.create({
    userId: legacy.id, amountMl: 250, drankAt: new Date(), idempotencyKey: 'legacy-record'
  });
  await repository.updateDailyTarget(legacy.id, '2026-07-23', 9);
  await repository.migrateLegacyUserData(legacy.id, target.phone);
  await repository.migrateLegacyUserData(legacy.id, target.phone);
  assert.equal(repository.records[0].userId, target.id);
  assert.equal(repository.goals.size, 1);
  assert.equal(Array.from(repository.goals.values())[0].userId, target.id);
});
