import crypto from 'node:crypto';
import express from 'express';
import { AppError } from './errors.js';

export function createApp(service, authService) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '16kb' }));

  app.get('/api/health', asyncHandler(async (_request, response) => {
    response.json({ success: true, data: await service.health() });
  }));

  app.post('/api/auth/login', asyncHandler(async (request, response) => {
    const result = await authService.login(request.body?.phone, request.body?.password);
    response.json({ success: true, data: result });
  }));

  app.post('/api/auth/refresh', asyncHandler(async (request, response) => {
    const result = await authService.refresh(request.body?.refreshToken);
    response.json({ success: true, data: result });
  }));

  const requireAuth = asyncHandler(async (request, _response, next) => {
    const authorization = request.get('Authorization') || '';
    const token = authorization.startsWith('Bearer ') ? authorization.slice(7) : '';
    request.auth = await authService.authenticate(token);
    next();
  });

  app.get('/api/auth/me', requireAuth, asyncHandler(async (request, response) => {
    response.json({ success: true, data: { user: request.auth.user } });
  }));

  app.post('/api/auth/logout', requireAuth, asyncHandler(async (request, response) => {
    await authService.logout(request.auth.sessionId);
    response.json({ success: true, data: { loggedOut: true } });
  }));

  app.use('/api/water', requireAuth);

  app.get('/api/water/today', asyncHandler(async (request, response) => {
    response.json({ success: true, data: await service.today(request.auth.userId) });
  }));

  app.get('/api/water/settings', asyncHandler(async (request, response) => {
    response.json({ success: true, data: await service.settings(request.auth.userId) });
  }));

  app.put('/api/water/settings', asyncHandler(async (request, response) => {
    const dailyTarget = request.body?.dailyTarget;
    assertInteger(dailyTarget, 1, 30, 'INVALID_TARGET', 'dailyTarget 必须是 1 到 30 之间的整数。');
    response.json({ success: true, data: await service.updateSettings(request.auth.userId, dailyTarget) });
  }));

  app.post('/api/water/check-in', asyncHandler(async (request, response) => {
    const providedKey = request.get('Idempotency-Key');
    if (providedKey && providedKey.length > 128) {
      throw new AppError(400, 'INVALID_IDEMPOTENCY_KEY', 'Idempotency-Key 不能超过 128 个字符。');
    }
    const result = await service.checkIn(request.auth.userId, providedKey || crypto.randomUUID());
    response.status(result.created ? 201 : 200).json({ success: true, data: result });
  }));

  app.delete('/api/water/records/:id', asyncHandler(async (request, response) => {
    const recordId = Number(request.params.id);
    assertInteger(recordId, 1, Number.MAX_SAFE_INTEGER, 'INVALID_RECORD_ID', '记录 ID 无效。');
    response.json({ success: true, data: await service.deleteRecord(request.auth.userId, recordId) });
  }));

  app.get('/api/water/day', asyncHandler(async (request, response) => {
    const date = String(request.query.date || '');
    response.json({ success: true, data: await service.day(request.auth.userId, date) });
  }));

  app.get('/api/water/stats', asyncHandler(async (request, response) => {
    const period = String(request.query.period || 'week');
    if (!['week', 'month'].includes(period)) {
      throw new AppError(400, 'INVALID_PERIOD', 'period 只能是 week 或 month。');
    }
    const anchor = request.query.anchor === undefined ? undefined : String(request.query.anchor);
    response.json({ success: true, data: await service.stats(request.auth.userId, period, anchor) });
  }));

  app.get('/api/water/history', asyncHandler(async (request, response) => {
    const days = Number(request.query.days || 7);
    assertInteger(days, 1, 31, 'INVALID_DAYS', 'days 必须是 1 到 31 之间的整数。');
    response.json({ success: true, data: await service.history(request.auth.userId, days) });
  }));

  app.use((_request, _response, next) => next(new AppError(404, 'NOT_FOUND', '接口不存在。')));
  app.use((error, _request, response, _next) => {
    const initializationError = typeof error?.code === 'string' &&
      ['ER_NO_REFERENCED_ROW_2', 'ER_NO_SUCH_TABLE'].includes(error.code);
    const databaseError = typeof error?.code === 'string' &&
      (error.code.startsWith('ER_') || ['ECONNREFUSED', 'ETIMEDOUT', 'PROTOCOL_CONNECTION_LOST'].includes(error.code));
    const status = error instanceof AppError ? error.status : (databaseError ? 503 : 500);
    const code = error instanceof AppError ? error.code :
      (initializationError ? 'DB_INITIALIZATION_INCOMPLETE' : (databaseError ? 'DB_UNAVAILABLE' : 'INTERNAL_ERROR'));
    const message = error instanceof AppError ? error.message :
      (initializationError ? '数据库初始化不完整，请重新执行 server/sql/init.sql。' :
        (databaseError ? '数据库暂时不可用，请稍后重试。' : '服务暂时不可用，请稍后重试。'));
    if (!(error instanceof AppError)) {
      console.error('API request failed', { code: error?.code || 'UNKNOWN', message: error?.message || String(error) });
    }
    response.status(status).json({ success: false, error: { code, message } });
  });
  return app;
}

function assertInteger(value, minimum, maximum, code, message) {
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new AppError(400, code, message);
  }
}

function asyncHandler(handler) {
  return (request, response, next) => Promise.resolve(handler(request, response, next)).catch(next);
}
