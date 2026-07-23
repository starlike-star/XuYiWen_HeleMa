import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';
import { MockWaterRepository } from '../src/repositories/mockWaterRepository.js';
import { WaterService } from '../src/waterService.js';
import { AuthService } from '../src/auth/authService.js';

const repository = new MockWaterRepository();
const authConfig = {
  accessTokenSecret: 'smoke-secret', accessTokenTtlSeconds: 1800,
  refreshTokenTtlSeconds: 2592000, bcryptRounds: 10,
  loginFailureLimit: 5, loginLockSeconds: 900
};
const config = { dataMode: 'mock', timeZone: 'Asia/Shanghai', auth: authConfig };
const auth = new AuthService(repository, authConfig);
await auth.createAccount('13800000000', 'Password1!', '冒烟用户');
const app = createApp(new WaterService(repository, config), auth);
const server = await new Promise((resolve) => {
  const instance = app.listen(0, '127.0.0.1', () => resolve(instance));
});
const baseUrl = `http://127.0.0.1:${server.address().port}`;

try {
  const health = await (await fetch(`${baseUrl}/api/health`)).json();
  assert.equal(health.data.database.status, 'not_required');
  const login = await (await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone: '13800000000', password: 'Password1!' })
  })).json();
  const headers = { Authorization: `Bearer ${login.data.accessToken}` };
  const settings = await (await fetch(`${baseUrl}/api/water/settings`, { headers })).json();
  assert.equal(settings.data.dailyTarget, 8);
  const checked = await (await fetch(`${baseUrl}/api/water/check-in`, {
    method: 'POST',
    headers: { ...headers, 'Content-Type': 'application/json', 'Idempotency-Key': 'smoke-check-in' },
    body: '{}'
  })).json();
  assert.equal(checked.data.today.count, 1);
  const day = await (await fetch(`${baseUrl}/api/water/day?date=${checked.data.today.date}`, { headers })).json();
  assert.equal(day.data.count, 1);
  const history = await (await fetch(`${baseUrl}/api/water/history?days=7`, { headers })).json();
  assert.equal(history.data.days.length, 7);
  const month = await (await fetch(`${baseUrl}/api/water/stats?period=month`, { headers })).json();
  assert.ok(month.data.days.length >= 28);
  const deleted = await (await fetch(`${baseUrl}/api/water/records/${checked.data.recordId}`, {
    method: 'DELETE', headers
  })).json();
  assert.equal(deleted.data.day.count, 0);
  console.log('Mock API smoke test passed.');
} finally {
  await new Promise((resolve) => server.close(resolve));
}
