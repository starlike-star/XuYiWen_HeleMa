import { http } from '@kit.NetworkKit';
import { API_BASE_URL_CANDIDATES, REQUEST_TIMEOUT_MS } from '../config/AppConfig';
import { ApiEnvelope, HealthData, HistoryData, TodayData } from '../models/WaterModels';

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

  getActiveBaseUrl(): string {
    return this.activeBaseUrl;
  }

  async probeHealth(): Promise<HealthData> {
    let lastMessage: string = '无法连接喝了吗服务，请确认后端已启动。';
    for (let index: number = 0; index < API_BASE_URL_CANDIDATES.length; index++) {
      const candidate: string = API_BASE_URL_CANDIDATES[index];
      try {
        const health: HealthData = await this.requestAt<HealthData>(candidate, '/api/health', http.RequestMethod.GET);
        this.activeBaseUrl = candidate;
        return health;
      } catch (error) {
        if (error instanceof Error) {
          lastMessage = error.message;
        }
      }
    }
    throw new WaterApiError('SERVICE_UNREACHABLE', `${lastMessage} 请在 AppConfig.ets 中配置可达地址。`);
  }

  async getToday(): Promise<TodayData> {
    return this.request<TodayData>('/api/water/today', http.RequestMethod.GET);
  }

  async getHistory(): Promise<HistoryData> {
    return this.request<HistoryData>('/api/water/history?days=7', http.RequestMethod.GET);
  }

  async checkIn(amountMl: number = 250): Promise<TodayData> {
    const key: string = `hylm-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
    return this.request<TodayData>(
      '/api/water/check-in',
      http.RequestMethod.POST,
      JSON.stringify({ amountMl: amountMl }),
      key
    );
  }

  private async request<T>(path: string, method: http.RequestMethod, body: string = '', idempotencyKey: string = ''): Promise<T> {
    if (this.activeBaseUrl.length === 0) {
      await this.probeHealth();
    }
    return this.requestAt<T>(this.activeBaseUrl, path, method, body, idempotencyKey);
  }

  private async requestAt<T>(baseUrl: string, path: string, method: http.RequestMethod,
    body: string = '', idempotencyKey: string = ''): Promise<T> {
    const client: http.HttpRequest = http.createHttp();
    const options: http.HttpRequestOptions = {
      method: method,
      connectTimeout: REQUEST_TIMEOUT_MS,
      readTimeout: REQUEST_TIMEOUT_MS,
      expectDataType: http.HttpDataType.STRING,
      header: {
        'Content-Type': 'application/json',
        'Idempotency-Key': idempotencyKey
      }
    };
    if (method === http.RequestMethod.POST) {
      options.extraData = body;
    }

    try {
      const response: http.HttpResponse = await client.request(`${baseUrl}${path}`, options);
      const text: string = response.result as string;
      const envelope: ApiEnvelope<T> = JSON.parse(text) as ApiEnvelope<T>;
      if (!envelope.success || envelope.data === undefined) {
        const code: string = envelope.error?.code || 'API_ERROR';
        const message: string = envelope.error?.message || '服务返回了无法识别的响应。';
        throw new WaterApiError(code, message);
      }
      return envelope.data;
    } catch (error) {
      if (error instanceof WaterApiError) {
        throw error;
      }
      if (error instanceof Error) {
        throw new WaterApiError('NETWORK_ERROR', error.message);
      }
      throw new WaterApiError('NETWORK_ERROR', '网络请求失败。');
    } finally {
      client.destroy();
    }
  }
}
