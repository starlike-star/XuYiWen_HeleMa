import crypto from 'node:crypto';
import express from 'express';
import { AppError } from './errors.js';

export function createApp(service) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '16kb' }));

  app.get('/api/health', asyncHandler(async (_request, response) => {
    response.json({ success: true, data: await service.health() });
  }));

  app.get('/api/water/today', asyncHandler(async (_request, response) => {
    response.json({ success: true, data: await service.today() });
  }));

  app.post('/api/water/check-in', asyncHandler(async (request, response) => {
    const rawAmount = request.body?.amountMl;
    const amountMl = rawAmount === undefined ? 250 : rawAmount;
    if (!Number.isInteger(amountMl) || amountMl < 1 || amountMl > 2000) {
      throw new AppError(400, 'INVALID_AMOUNT', 'amountMl 必须是 1 到 2000 之间的整数。');
    }
    const providedKey = request.get('Idempotency-Key');
    if (providedKey && providedKey.length > 128) {
      throw new AppError(400, 'INVALID_IDEMPOTENCY_KEY', 'Idempotency-Key 不能超过 128 个字符。');
    }
    const key = providedKey || crypto.randomUUID();
    response.status(201).json({ success: true, data: await service.checkIn(amountMl, key) });
  }));

  app.get('/api/water/history', asyncHandler(async (request, response) => {
    const days = Number(request.query.days || 7);
    if (!Number.isInteger(days) || days < 1 || days > 31) {
      throw new AppError(400, 'INVALID_DAYS', 'days 必须是 1 到 31 之间的整数。');
    }
    response.json({ success: true, data: await service.history(days) });
  }));

  app.use((_request, _response, next) => next(new AppError(404, 'NOT_FOUND', '接口不存在。')));
  app.use((error, _request, response, _next) => {
    const databaseError = typeof error?.code === 'string' &&
      (error.code.startsWith('ER_') || ['ECONNREFUSED', 'ETIMEDOUT', 'PROTOCOL_CONNECTION_LOST'].includes(error.code));
    const status = error instanceof AppError ? error.status : (databaseError ? 503 : 500);
    const code = error instanceof AppError ? error.code : (databaseError ? 'DB_UNAVAILABLE' : 'INTERNAL_ERROR');
    const message = error instanceof AppError ? error.message :
      (databaseError ? '数据库暂时不可用，请稍后重试。' : '服务暂时不可用，请稍后重试。');
    response.status(status).json({ success: false, error: { code, message } });
  });
  return app;
}

function asyncHandler(handler) {
  return (request, response, next) => Promise.resolve(handler(request, response, next)).catch(next);
}
