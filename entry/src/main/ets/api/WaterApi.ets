import { http } from '@kit.NetworkKit';
import { API_BASE_URL_CANDIDATES, REQUEST_TIMEOUT_MS } from '../config/AppConfig';
import {
  ApiEnvelope, AuthTokens, CheckInData, DayData, DeleteRecordData, HealthData, HistoryData,
  LogoutData, MeData, StatsData, TodayData, UpdateSettingsData, WaterSettings
} from '../models/WaterModels';

export class WaterApiError extends Error {
  code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = 'WaterApiError';
    this.code = code;
  }
}

export class WaterApi {
  private activeBaseUrl: string = '';
  private accessToken: string = '';
  private refreshHandler: (() => Promise<boolean>) | null = null;

  setAccessToken(token: string): void {
    this.accessToken = token;
  }

  setRefreshHandler(handler: () => Promise<boolean>): void {
    this.refreshHandler = handler;
  }

  getActiveBaseUrl(): string {
    return this.activeBaseUrl;
  }

  async probeHealth(): Promise<HealthData> {
    let lastMessage: string = '无法连接喝了吗服务，请确认后端已启动。';
    const failures: string[] = [];
    for (let index: number = 0; index < API_BASE_URL_CANDIDATES.length; index++) {
      const candidate: string = API_BASE_URL_CANDIDATES[index];
      try {
        const health: HealthData = await this.requestAt<HealthData>(candidate, '/api/health', http.RequestMethod.GET);
        this.activeBaseUrl = candidate;
        return health;
      } catch (error) {
        if (error instanceof Error) lastMessage = error.message;
        failures.push(`${candidate.replace('http://', '')}：${lastMessage}`);
      }
    }
    throw new WaterApiError(
      'SERVICE_UNREACHABLE',
      `无法连接喝了吗 API。已尝试：${failures.join('；')}`
    );
  }

  async getToday(): Promise<TodayData> {
    return this.request<TodayData>('/api/water/today', http.RequestMethod.GET);
  }

  async login(phone: string, password: string): Promise<AuthTokens> {
    if (this.activeBaseUrl.length === 0) await this.probeHealth();
    return this.requestAt<AuthTokens>(
      this.activeBaseUrl, '/api/auth/login', http.RequestMethod.POST,
      JSON.stringify({ phone: phone, password: password }), '', false
    );
  }

  async me(): Promise<MeData> {
    return this.request<MeData>('/api/auth/me', http.RequestMethod.GET);
  }

  async refresh(refreshToken: string): Promise<AuthTokens> {
    if (this.activeBaseUrl.length === 0) await this.probeHealth();
    return this.requestAt<AuthTokens>(
      this.activeBaseUrl, '/api/auth/refresh', http.RequestMethod.POST,
      JSON.stringify({ refreshToken: refreshToken }), '', false
    );
  }

  async logout(): Promise<LogoutData> {
    return this.request<LogoutData>('/api/auth/logout', http.RequestMethod.POST, '{}');
  }

  async getHistory(): Promise<HistoryData> {
    return this.request<HistoryData>('/api/water/history?days=7', http.RequestMethod.GET);
  }

  async getSettings(): Promise<WaterSettings> {
    return this.request<WaterSettings>('/api/water/settings', http.RequestMethod.GET);
  }

  async updateSettings(dailyTarget: number): Promise<UpdateSettingsData> {
    return this.request<UpdateSettingsData>(
      '/api/water/settings', http.RequestMethod.PUT,
      JSON.stringify({ dailyTarget: dailyTarget })
    );
  }

  async getStats(period: string, anchor: string = ''): Promise<StatsData> {
    const suffix: string = anchor.length > 0 ? `&anchor=${anchor}` : '';
    return this.request<StatsData>(`/api/water/stats?period=${period}${suffix}`, http.RequestMethod.GET);
  }

  async getDay(date: string): Promise<DayData> {
    return this.request<DayData>(`/api/water/day?date=${date}`, http.RequestMethod.GET);
  }

  async checkIn(): Promise<CheckInData> {
    const key: string = `hylm-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
    return this.request<CheckInData>('/api/water/check-in', http.RequestMethod.POST, '{}', key);
  }

  async deleteRecord(recordId: number): Promise<DeleteRecordData> {
    return this.request<DeleteRecordData>(`/api/water/records/${recordId}`, http.RequestMethod.DELETE);
  }

  private async request<T>(path: string, method: http.RequestMethod, body: string = '',
    idempotencyKey: string = ''): Promise<T> {
    if (this.activeBaseUrl.length === 0) await this.probeHealth();
    try {
      return await this.requestAt<T>(this.activeBaseUrl, path, method, body, idempotencyKey);
    } catch (error) {
      if (error instanceof WaterApiError &&
        error.code === 'AUTHENTICATION_REQUIRED' &&
        this.refreshHandler !== null &&
        await this.refreshHandler()) {
        return this.requestAt<T>(this.activeBaseUrl, path, method, body, idempotencyKey);
      }
      if (error instanceof WaterApiError) throw error;
      if (error instanceof Error) throw new WaterApiError('API_ERROR', error.message);
      throw new WaterApiError('API_ERROR', '服务请求失败。');
    }
  }

  private async requestAt<T>(baseUrl: string, path: string, method: http.RequestMethod,
    body: string = '', idempotencyKey: string = '', includeAuthorization: boolean = true): Promise<T> {
    const client: http.HttpRequest = http.createHttp();
    const options: http.HttpRequestOptions = {
      method: method,
      connectTimeout: REQUEST_TIMEOUT_MS,
      readTimeout: REQUEST_TIMEOUT_MS,
      expectDataType: http.HttpDataType.STRING,
      header: {
        'Content-Type': 'application/json',
        'Idempotency-Key': idempotencyKey,
        'Authorization': includeAuthorization && this.accessToken.length > 0 ? `Bearer ${this.accessToken}` : ''
      }
    };
    if (method === http.RequestMethod.POST || method === http.RequestMethod.PUT) options.extraData = body;

    try {
      const response: http.HttpResponse = await client.request(`${baseUrl}${path}`, options);
      const resultText: string = response.result as string;
      const envelope: ApiEnvelope<T> = JSON.parse(resultText) as ApiEnvelope<T>;
      if (!envelope.success || envelope.data === undefined) {
        throw new WaterApiError(
          envelope.error?.code || 'API_ERROR',
          envelope.error?.message || '服务返回了无法识别的响应。'
        );
      }
      return envelope.data;
    } catch (error) {
      if (error instanceof WaterApiError) throw error;
      if (error instanceof Error) throw new WaterApiError('NETWORK_ERROR', error.message);
      throw new WaterApiError('NETWORK_ERROR', '网络请求失败。');
    } finally {
      client.destroy();
    }
  }
}
