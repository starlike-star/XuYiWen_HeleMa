import { WaterApi, WaterApiError } from '../api/WaterApi';
import {
  CheckInData, DayData, DeleteRecordData, HealthData, HistoryData, HistoryDay, ReminderConfig,
  ReminderState, StatsData, TodayData, UpdateSettingsData, WaterRecord, WaterSettings
} from '../models/WaterModels';

const EMPTY_TODAY: TodayData = {
  date: '', count: 0, target: 8, completed: false, totalAmountMl: 0, records: []
};

const EMPTY_STATS: StatsData = {
  period: 'week', anchor: '', range: { startDate: '', endDate: '' }, todayDate: '',
  summary: { totalCount: 0, completedDays: 0, currentStreak: 0, longestStreak: 0 }, days: []
};

@Observed
export class WaterStore {
  private api: WaterApi = new WaterApi();
  private refreshVersion: number = 0;
  private undoVersion: number = 0;
  private feedbackVersion: number = 0;
  private reminderSync: (today: TodayData) => Promise<void> = async (_today: TodayData) => {};
  private widgetSync: (today: TodayData) => Promise<void> = async (_today: TodayData) => {};

  getApi(): WaterApi {
    return this.api;
  }

  resetUserData(): void {
    this.refreshVersion += 1;
    this.today = EMPTY_TODAY;
    this.history = [];
    this.settings = { dailyTarget: 8, goalEffectiveDate: null };
    this.selectedDate = '';
    this.selectedDay = null;
    this.undoVisible = false;
    this.undoRecordId = 0;
    this.errorCode = '';
    this.errorMessage = '';
  }

  isLoading: boolean = true;
  isSubmitting: boolean = false;
  isSavingSettings: boolean = false;
  isDayLoading: boolean = false;
  errorMessage: string = '';
  errorCode: string = '';
  dataMode: string = '';
  databaseStatus: string = '';
  activeBaseUrl: string = '';
  today: TodayData = EMPTY_TODAY;
  history: HistoryDay[] = [];
  settings: WaterSettings = { dailyTarget: 8, goalEffectiveDate: null };
  weekStats: StatsData = EMPTY_STATS;
  monthStats: StatsData = {
    period: 'month', anchor: '', range: { startDate: '', endDate: '' }, todayDate: '',
    summary: { totalCount: 0, completedDays: 0, currentStreak: 0, longestStreak: 0 }, days: []
  };
  selectedDay: DayData | null = null;
  selectedDate: string = '';
  feedbackText: string = '';
  feedbackToken: number = 0;
  celebrationToken: number = 0;
  undoRecordId: number = 0;
  undoVisible: boolean = false;
  reminderConfig: ReminderConfig = {
    enabled: false, startHour: 9, startMinute: 0, endHour: 21, endMinute: 0,
    intervalMinutes: 120, configVersion: 1
  };
  reminderState: ReminderState = {
    status: 'disabled', scheduledCount: 0, expectedCount: 0, message: '提醒未开启'
  };

  setReminderSync(sync: (today: TodayData) => Promise<void>): void {
    this.reminderSync = sync;
  }

  setWidgetSync(sync: (today: TodayData) => Promise<void>): void {
    this.widgetSync = sync;
  }

  async load(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    this.errorCode = '';
    try {
      let health: HealthData = await this.api.probeHealth();
      if (health.database.status === 'unavailable') {
        await this.delay(1000);
        health = await this.api.probeHealth();
      }
      this.dataMode = health.dataMode;
      this.databaseStatus = health.database.status;
      this.activeBaseUrl = this.api.getActiveBaseUrl();
      if (health.database.status === 'not_configured') {
        throw new WaterApiError('DB_NOT_CONFIGURED', '数据库连接尚未配置，请填写环境变量后重新启动服务。');
      }
      if (health.database.status === 'unavailable') {
        throw new WaterApiError(
          'DB_UNAVAILABLE',
          `API 已连接（${this.activeBaseUrl}），但数据库暂时不可用，请检查 Node 服务终端与 MySQL。`
        );
      }
      await this.refreshAfterMutation('');
    } catch (error) {
      this.captureError(error);
    } finally {
      this.isLoading = false;
    }
  }

  async refreshAfterMutation(affectedDate: string): Promise<void> {
    const version: number = ++this.refreshVersion;
    try {
      const today: TodayData = await this.api.getToday();
      if (version !== this.refreshVersion) return;
      this.today = today;
      this.widgetSync(today);
      const settings: WaterSettings = await this.api.getSettings();
      if (version !== this.refreshVersion) return;
      this.settings = settings;
      const history: HistoryData = await this.api.getHistory();
      if (version !== this.refreshVersion) return;
      this.history = history.days;
      const week: StatsData = await this.api.getStats('week', today.date);
      if (version !== this.refreshVersion) return;
      this.weekStats = week;
      const monthAnchor: string = this.monthStats.anchor.length > 0 ? this.monthStats.anchor : today.date;
      const month: StatsData = await this.api.getStats('month', monthAnchor);
      if (version !== this.refreshVersion) return;
      this.monthStats = month;
      if (this.selectedDate.length > 0 && (affectedDate.length === 0 || affectedDate === this.selectedDate)) {
        this.selectedDay = await this.api.getDay(this.selectedDate);
        if (version !== this.refreshVersion) return;
      }
      // 提醒系统属于附加能力，不能阻塞首页、统计和设置数据刷新。
      // 具体错误由 Main.reconcileReminder 转换为提醒状态，业务数据仍保持可用。
      this.reminderSync(this.today);
    } catch (error) {
      this.captureError(error);
    }
  }

  async loadMonth(anchor: string): Promise<void> {
    try {
      this.monthStats = await this.api.getStats('month', anchor);
    } catch (error) {
      this.captureError(error);
    }
  }

  async selectDay(date: string): Promise<void> {
    this.selectedDate = date;
    this.isDayLoading = true;
    try {
      this.selectedDay = await this.api.getDay(date);
    } catch (error) {
      this.captureError(error);
    } finally {
      this.isDayLoading = false;
    }
  }

  closeSelectedDay(): void {
    this.selectedDate = '';
    this.selectedDay = null;
  }

  async checkIn(): Promise<void> {
    if (this.isSubmitting || this.isLoading) return;
    this.isSubmitting = true;
    this.errorMessage = '';
    this.errorCode = '';
    const wasCompleted: boolean = this.today.completed;
    try {
      const result: CheckInData = await this.api.checkIn();
      this.today = result.today;
      if (result.created) {
        this.showFeedback(result.today.completed ? '今日饮水目标已完成' : `第 ${result.today.count} 次打卡成功`);
        if (!wasCompleted && result.today.completed) this.celebrationToken += 1;
        this.showUndo(result.recordId);
      }
      await this.refreshAfterMutation(result.today.date);
    } catch (error) {
      this.captureError(error);
    } finally {
      this.isSubmitting = false;
    }
  }

  private showUndo(recordId: number): void {
    this.undoRecordId = recordId;
    this.undoVisible = true;
    const version: number = ++this.undoVersion;
    setTimeout(() => {
      if (version === this.undoVersion) this.undoVisible = false;
    }, 5000);
  }

  async undoLastCheckIn(): Promise<void> {
    if (!this.undoVisible || this.undoRecordId <= 0) return;
    const recordId: number = this.undoRecordId;
    this.undoVisible = false;
    this.undoVersion += 1;
    await this.deleteRecord(recordId, true);
  }

  async deleteRecord(recordId: number, isUndo: boolean = false): Promise<void> {
    try {
      const result: DeleteRecordData = await this.api.deleteRecord(recordId);
      this.showFeedback(isUndo ? '已撤销刚才的打卡' : '记录已删除');
      await this.refreshAfterMutation(result.affectedDate);
    } catch (error) {
      this.captureError(error);
    }
  }

  async saveSettings(dailyTarget: number): Promise<void> {
    if (this.isSavingSettings) return;
    this.isSavingSettings = true;
    try {
      const result: UpdateSettingsData = await this.api.updateSettings(dailyTarget);
      this.settings = result.settings;
      this.today = result.today;
      this.showFeedback('饮水设置已保存');
      await this.refreshAfterMutation(result.today.date);
    } catch (error) {
      this.captureError(error);
    } finally {
      this.isSavingSettings = false;
    }
  }

  progress(): number {
    if (this.today.target <= 0) return 0;
    return Math.min(this.today.count / this.today.target, 1);
  }

  remaining(): number {
    return Math.max(this.today.target - this.today.count, 0);
  }

  dynamicHint(): string {
    if (this.today.completed) return '今天的目标完成啦，继续保持舒展';
    if (this.today.count === 0) return '今天喝水了吗？';
    return `距离今日目标还差 ${this.remaining()} 次。`;
  }

  records(): WaterRecord[] {
    return this.today.records;
  }

  private showFeedback(message: string): void {
    this.feedbackText = message;
    this.feedbackToken += 1;
    const version: number = ++this.feedbackVersion;
    setTimeout(() => {
      if (version === this.feedbackVersion) this.feedbackText = '';
    }, 2200);
  }

  private delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, milliseconds);
    });
  }

  clearError(): void {
    this.errorCode = '';
    this.errorMessage = '';
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
