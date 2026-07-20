import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';
import { MockWaterRepository } from '../src/repositories/mockWaterRepository.js';
import { WaterService } from '../src/waterService.js';

const repository = new MockWaterRepository();
const config = { dataMode: 'mock', timeZone: 'Asia/Shanghai', defaultUserId: 1 };
const app = createApp(new WaterService(repository, config));
const server = await new Promise((resolve) => {
  const instance = app.listen(0, '127.0.0.1', () => resolve(instance));
});
const baseUrl = `http://127.0.0.1:${server.address().port}`;

try {
  const health = await (await fetch(`${baseUrl}/api/health`)).json();
  assert.equal(health.data.database.status, 'not_required');
  const checked = await (await fetch(`${baseUrl}/api/water/check-in`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Idempotency-Key': 'smoke-check-in' },
    body: '{}'
  })).json();
  assert.equal(checked.data.count, 1);
  const today = await (await fetch(`${baseUrl}/api/water/today`)).json();
  assert.equal(today.data.count, 1);
  const history = await (await fetch(`${baseUrl}/api/water/history?days=7`)).json();
  assert.equal(history.data.days.length, 7);
  console.log('Mock API smoke test passed.');
} finally {
  await new Promise((resolve) => server.close(resolve));
}
