import { WaterApi, WaterApiError } from '../api/WaterApi';
import { HealthData, HistoryDay, HistoryData, TodayData, WaterRecord } from '../models/WaterModels';

@Observed
export class WaterStore {
  private api: WaterApi = new WaterApi();

  isLoading: boolean = true;
  isSubmitting: boolean = false;
  errorMessage: string = '';
  errorCode: string = '';
  dataMode: string = '';
  databaseStatus: string = '';
  activeBaseUrl: string = '';
  today: TodayData = {
    date: '', count: 0, target: 8, completed: false, records: []
  };
  history: HistoryDay[] = [];
  feedbackText: string = '';
  feedbackToken: number = 0;
  celebrationToken: number = 0;

  async load(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    this.errorCode = '';
    try {
      const health: HealthData = await this.api.probeHealth();
      this.dataMode = health.dataMode;
      this.databaseStatus = health.database.status;
      this.activeBaseUrl = this.api.getActiveBaseUrl();
      if (health.database.status === 'not_configured') {
        throw new WaterApiError('DB_NOT_CONFIGURED', '数据库连接尚未配置，请填写环境变量后重新启动服务。');
      }
      if (health.database.status === 'unavailable') {
        throw new WaterApiError('DB_UNAVAILABLE', '数据库暂时不可用，请稍后重试。');
      }
      const today: TodayData = await this.api.getToday();
      const history: HistoryData = await this.api.getHistory();
      this.today = today;
      this.history = history.days;
    } catch (error) {
      this.captureError(error);
    } finally {
      this.isLoading = false;
    }
  }

  async refreshHistory(): Promise<void> {
    if (this.errorCode.length > 0) return;
    try {
      const history: HistoryData = await this.api.getHistory();
      this.history = history.days;
    } catch (error) {
      this.captureError(error);
    }
  }

  async checkIn(): Promise<void> {
    if (this.isSubmitting || this.isLoading) return;
    this.isSubmitting = true;
    this.errorMessage = '';
    this.errorCode = '';
    const previousCount: number = this.today.count;
    try {
      const today: TodayData = await this.api.checkIn();
      this.today = today;
      this.feedbackText = today.count >= 8 ? '今日饮水目标已完成' : `第 ${today.count} 次打卡成功`;
      this.feedbackToken += 1;
      const currentToken: number = this.feedbackToken;
      setTimeout(() => {
        if (this.feedbackToken === currentToken) this.feedbackText = '';
      }, 1900);
      if (previousCount < 8 && today.count >= 8) {
        this.celebrationToken += 1;
      }
      await this.refreshHistory();
    } catch (error) {
      this.captureError(error);
    } finally {
      this.isSubmitting = false;
    }
  }

  progress(): number {
    return Math.min(this.today.count / 8, 1);
  }

  remaining(): number {
    return Math.max(8 - this.today.count, 0);
  }

  dynamicHint(): string {
    if (this.today.completed) return '今天的目标完成啦，继续保持舒展。';
    if (this.today.count === 0) return '今天喝水了吗？';
    return `距离今日目标还差 ${this.remaining()} 次。`;
  }

  records(): WaterRecord[] {
    return this.today.records;
  }

  private captureError(error: Object): void {
    if (error instanceof WaterApiError) {
      this.errorCode = error.code;
      this.errorMessage = error.message;
    } else if (error instanceof Error) {
      this.errorCode = 'UNKNOWN_ERROR';
      this.errorMessage = error.message;
    } else {
      this.errorCode = 'UNKNOWN_ERROR';
      this.errorMessage = '发生未知错误，请重试。';
    }
  }
}
