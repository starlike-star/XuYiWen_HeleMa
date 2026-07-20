import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';
import { createApp } from '../src/app.js';
import { MockWaterRepository } from '../src/repositories/mockWaterRepository.js';
import { UnconfiguredRepository } from '../src/repositories/unconfiguredRepository.js';
import { WaterService } from '../src/waterService.js';

const fixedNow = new Date('2026-07-19T10:00:00.000Z');
const baseConfig = {
  dataMode: 'mock',
  timeZone: 'Asia/Shanghai',
  defaultUserId: 1
};

let server;
let baseUrl;

async function start(repository = new MockWaterRepository(), config = baseConfig) {
  const service = new WaterService(repository, config, () => new Date(fixedNow));
  const app = createApp(service);
  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', resolve);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
  return repository;
}

beforeEach(async () => start());
afterEach(async () => new Promise((resolve) => server.close(resolve)));

test('health 区分 Mock 模式且服务可用', async () => {
  const response = await fetch(`${baseUrl}/api/health`);
  const body = await response.json();
  assert.equal(body.data.service, 'up');
  assert.equal(body.data.dataMode, 'mock');
  assert.equal(body.data.database.status, 'not_required');
});

test('health 可表达数据库已连接和不可用', async () => {
  const connectedService = new WaterService({
    health: async () => ({ status: 'connected', message: '数据库连接正常。' })
  }, { ...baseConfig, dataMode: 'mysql' }, () => new Date(fixedNow));
  const unavailableService = new WaterService({
    health: async () => ({ status: 'unavailable', message: '数据库暂时不可用。' })
  }, { ...baseConfig, dataMode: 'mysql' }, () => new Date(fixedNow));
  assert.equal((await connectedService.health()).database.status, 'connected');
  assert.equal((await unavailableService.health()).database.status, 'unavailable');
});

test('今日初始为空并使用固定目标 8', async () => {
  const body = await (await fetch(`${baseUrl}/api/water/today`)).json();
  assert.equal(body.data.date, '2026-07-19');
  assert.equal(body.data.count, 0);
  assert.equal(body.data.target, 8);
  assert.equal(body.data.completed, false);
});

test('打卡支持饮水量并对幂等键去重', async () => {
  const options = {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Idempotency-Key': 'same-key' },
    body: JSON.stringify({ amountMl: 360 })
  };
  const first = await (await fetch(`${baseUrl}/api/water/check-in`, options)).json();
  const second = await (await fetch(`${baseUrl}/api/water/check-in`, options)).json();
  assert.equal(first.data.count, 1);
  assert.equal(first.data.records[0].amountMl, 360);
  assert.equal(first.data.created, true);
  assert.equal(second.data.count, 1);
  assert.equal(second.data.created, false);
});

test('第 8 次完成，超过目标仍可打卡', async () => {
  for (let index = 1; index <= 9; index += 1) {
    const response = await fetch(`${baseUrl}/api/water/check-in`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Idempotency-Key': `key-${index}` },
      body: '{}'
    });
    assert.equal(response.status, 201);
  }
  const today = await (await fetch(`${baseUrl}/api/water/today`)).json();
  assert.equal(today.data.count, 9);
  assert.equal(today.data.completed, true);
});

test('最近 7 天返回连续日期并补零', async () => {
  const history = await (await fetch(`${baseUrl}/api/water/history?days=7`)).json();
  assert.equal(history.data.days.length, 7);
  assert.deepEqual(history.data.days.map((item) => item.date), [
    '2026-07-13', '2026-07-14', '2026-07-15', '2026-07-16',
    '2026-07-17', '2026-07-18', '2026-07-19'
  ]);
  assert.ok(history.data.days.every((item) => item.count === 0));
});

test('Asia/Shanghai 的零点边界由服务端判定', async () => {
  const repository = new MockWaterRepository();
  await repository.create({
    userId: 1,
    amountMl: 250,
    drankAt: new Date('2026-07-18T16:00:00.000Z'),
    idempotencyKey: 'midnight'
  });
  const service = new WaterService(repository, baseConfig, () => new Date('2026-07-18T16:01:00.000Z'));
  const today = await service.today();
  assert.equal(today.date, '2026-07-19');
  assert.equal(today.count, 1);
});

test('数据库未配置返回结构化错误', async () => {
  await new Promise((resolve) => server.close(resolve));
  await start(new UnconfiguredRepository(), { ...baseConfig, dataMode: 'mysql' });
  const health = await (await fetch(`${baseUrl}/api/health`)).json();
  assert.equal(health.data.database.status, 'not_configured');
  const response = await fetch(`${baseUrl}/api/water/today`);
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error.code, 'DB_NOT_CONFIGURED');
});

test('非法参数使用统一错误结构', async () => {
  const response = await fetch(`${baseUrl}/api/water/check-in`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ amountMl: 0 })
  });
  const body = await response.json();
  assert.equal(response.status, 400);
  assert.equal(body.success, false);
  assert.equal(body.error.code, 'INVALID_AMOUNT');
});
