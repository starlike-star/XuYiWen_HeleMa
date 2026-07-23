import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';
import { createApp } from '../src/app.js';
import { MockWaterRepository } from '../src/repositories/mockWaterRepository.js';
import { UnconfiguredRepository } from '../src/repositories/unconfiguredRepository.js';
import { StreakService } from '../src/streakService.js';
import { WaterService } from '../src/waterService.js';
import { AuthService } from '../src/auth/authService.js';

const fixedNow = new Date('2026-07-19T10:00:00.000Z');
const authConfig = {
  accessTokenSecret: 'test-secret', accessTokenTtlSeconds: 1800,
  refreshTokenTtlSeconds: 2592000, bcryptRounds: 10,
  loginFailureLimit: 5, loginLockSeconds: 900
};
const baseConfig = { dataMode: 'mock', timeZone: 'Asia/Shanghai', auth: authConfig };

let server;
let baseUrl;
let repository;
let accessToken;

async function start(nextRepository = new MockWaterRepository(), config = baseConfig,
  authRepository = nextRepository) {
  repository = nextRepository;
  const service = new WaterService(repository, config, () => new Date(fixedNow));
  const auth = new AuthService(authRepository, authConfig, () => new Date(fixedNow));
  await auth.createAccount('13800000000', 'Password1!', '测试用户');
  accessToken = (await auth.login('13800000000', 'Password1!')).accessToken;
  const app = createApp(service, auth);
  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', resolve);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
}

async function json(path, options) {
  const requestOptions = { ...(options || {}), headers: { ...(options?.headers || {}) } };
  if (path.startsWith('/api/water')) requestOptions.headers.Authorization = `Bearer ${accessToken}`;
  const response = await fetch(`${baseUrl}${path}`, requestOptions);
  return { response, body: await response.json() };
}

async function checkIn(key) {
  return json('/api/water/check-in', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Idempotency-Key': key },
    body: '{}'
  });
}

beforeEach(async () => start());
afterEach(async () => new Promise((resolve) => server.close(resolve)));

test('health 区分服务与数据模式', async () => {
  const { body } = await json('/api/health');
  assert.equal(body.data.service, 'up');
  assert.equal(body.data.dataMode, 'mock');
  assert.equal(body.data.database.status, 'not_required');
});

test('默认设置和空的今日统计使用 8 次目标', async () => {
  const settings = await json('/api/water/settings');
  const today = await json('/api/water/today');
  assert.deepEqual(settings.body.data, { dailyTarget: 8, goalEffectiveDate: null });
  assert.equal(today.body.data.target, 8);
  assert.equal(today.body.data.totalAmountMl, 0);
});

test('打卡返回创建、幂等重放、记录 ID 和最新 today', async () => {
  const first = await checkIn('same-key');
  const second = await checkIn('same-key');
  assert.equal(first.response.status, 201);
  assert.equal(first.body.data.created, true);
  assert.equal(first.body.data.idempotentReplay, false);
  assert.equal(first.body.data.today.count, 1);
  assert.equal(first.body.data.today.totalAmountMl, 250);
  assert.equal(second.response.status, 200);
  assert.equal(second.body.data.created, false);
  assert.equal(second.body.data.idempotentReplay, true);
  assert.equal(second.body.data.recordId, first.body.data.recordId);
  assert.equal(second.body.data.today.count, 1);
});

test('目标同日更新只保留一条，打卡使用固定记录水量', async () => {
  await json('/api/water/settings', {
    method: 'PUT', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ dailyTarget: 10 })
  });
  const changed = await json('/api/water/settings', {
    method: 'PUT', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ dailyTarget: 6 })
  });
  const checked = await checkIn('uses-default');
  assert.equal(changed.body.data.today.target, 6);
  assert.equal(repository.goals.size, 1);
  assert.equal(checked.body.data.today.records[0].amountMl, 250);
});

test('修改目标立即反转今天完成状态', async () => {
  for (let index = 0; index < 8; index += 1) await checkIn(`target-${index}`);
  const raised = await json('/api/water/settings', {
    method: 'PUT', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ dailyTarget: 10 })
  });
  assert.equal(raised.body.data.today.completed, false);
  const lowered = await json('/api/water/settings', {
    method: 'PUT', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ dailyTarget: 6 })
  });
  assert.equal(lowered.body.data.today.completed, true);
});

test('删除返回受影响日期与最新日期统计', async () => {
  const checked = await checkIn('delete-me');
  const recordId = checked.body.data.recordId;
  const deleted = await json(`/api/water/records/${recordId}`, { method: 'DELETE' });
  assert.equal(deleted.body.data.deletedRecordId, recordId);
  assert.equal(deleted.body.data.affectedDate, '2026-07-19');
  assert.equal(deleted.body.data.day.count, 0);
  const missing = await json(`/api/water/records/${recordId}`, { method: 'DELETE' });
  assert.equal(missing.response.status, 404);
  assert.equal(missing.body.error.code, 'RECORD_NOT_FOUND');
});

test('日期详情返回单条水量和累计毫升数', async () => {
  await checkIn('amount-a');
  await checkIn('amount-b');
  const day = await json('/api/water/day?date=2026-07-19');
  assert.equal(day.body.data.count, 2);
  assert.equal(day.body.data.totalAmountMl, 500);
  assert.deepEqual(day.body.data.records.map((record) => record.amountMl), [250, 250]);
});

test('周和月统计返回完整连续日期且只统计次数', async () => {
  await checkIn('stats-one');
  const week = await json('/api/water/stats?period=week&anchor=2026-07-19');
  const month = await json('/api/water/stats?period=month&anchor=2026-07-01');
  assert.equal(week.body.data.days.length, 7);
  assert.deepEqual(week.body.data.range, { startDate: '2026-07-13', endDate: '2026-07-19' });
  assert.equal(week.body.data.summary.totalCount, 1);
  assert.equal(month.body.data.days.length, 31);
  assert.equal(month.body.data.days[0].date, '2026-07-01');
  assert.equal(month.body.data.days[30].date, '2026-07-31');
  assert.ok(month.body.data.days.every((day) => !Object.hasOwn(day, 'amountMl')));
});

test('连续达标 Service 使用聚合行和历史目标', () => {
  const service = new StreakService();
  const result = service.calculate([
    { date: '2026-07-15', count: 8 },
    { date: '2026-07-16', count: 8 },
    { date: '2026-07-18', count: 6 }
  ], [
    { effectiveDate: '2026-07-18', targetCount: 6 }
  ], '2026-07-19', 'Asia/Shanghai');
  assert.deepEqual(result, { current: 1, longest: 2 });
});

test('history 继续返回完整连续七天并使用动态目标', async () => {
  await json('/api/water/settings', {
    method: 'PUT', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ dailyTarget: 5 })
  });
  const history = await json('/api/water/history?days=7');
  assert.deepEqual(history.body.data.days.map((day) => day.date), [
    '2026-07-13', '2026-07-14', '2026-07-15', '2026-07-16',
    '2026-07-17', '2026-07-18', '2026-07-19'
  ]);
  assert.equal(history.body.data.days[6].target, 5);
  assert.equal(history.body.data.days[5].target, 8);
});

test('数据库未配置时业务接口返回结构化错误', async () => {
  await new Promise((resolve) => server.close(resolve));
  await start(new UnconfiguredRepository(), { ...baseConfig, dataMode: 'mysql' }, new MockWaterRepository());
  const health = await json('/api/health');
  const today = await json('/api/water/today');
  assert.equal(health.body.data.database.status, 'not_configured');
  assert.equal(today.response.status, 503);
  assert.equal(today.body.error.code, 'DB_NOT_CONFIGURED');
});

test('非法设置、日期和统计周期使用统一错误结构', async () => {
  const setting = await json('/api/water/settings', {
    method: 'PUT', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ dailyTarget: 0 })
  });
  const day = await json('/api/water/day?date=not-a-date');
  const stats = await json('/api/water/stats?period=year');
  assert.equal(setting.body.error.code, 'INVALID_TARGET');
  assert.equal(day.body.error.code, 'INVALID_DATE');
  assert.equal(stats.body.error.code, 'INVALID_PERIOD');
});
