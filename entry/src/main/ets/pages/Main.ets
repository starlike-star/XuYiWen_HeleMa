import { common } from '@kit.AbilityKit';
import { GlassNavigation } from '../components/common/GlassNavigation';
import { StatusPanel } from '../components/common/StatusPanel';
import { ReminderConfig, TodayData } from '../models/WaterModels';
import { ReminderService, ReminderSnapshot } from '../services/ReminderService';
import { WaterStore } from '../store/WaterStore';
import { HomeView } from './views/HomeView';
import { SettingsView } from './views/SettingsView';
import { StatsView } from './views/StatsView';
import { LoginView } from './views/LoginView';
import { AuthSessionService, AuthState } from '../services/AuthSessionService';
import { ThemeMode, ThemeService } from '../services/ThemeService';
import { WidgetCacheService } from '../services/WidgetCacheService';

@Entry
@Component
struct Main {
  @State private selectedIndex: number = 0;
  @State private store: WaterStore = new WaterStore();
  @State private authState: AuthState = 'checking';
  @State private themeMode: ThemeMode = 'system';
  private reminderService: ReminderService | null = null;
  private authService: AuthSessionService | null = null;
  private themeService: ThemeService | null = null;
  private widgetCacheService: WidgetCacheService | null = null;

  aboutToAppear(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.reminderService = new ReminderService(context);
    this.themeService = new ThemeService(context);
    this.widgetCacheService = new WidgetCacheService(context);
    this.store.setWidgetSync(async (today: TodayData) => {
      if (this.widgetCacheService !== null) await this.widgetCacheService.update(today);
    });
    this.themeService.restore().then((mode: ThemeMode) => this.themeMode = mode);
    this.authService = new AuthSessionService(this.store.getApi());
    this.authService.setStateListener((state: AuthState) => this.authState = state);
    this.initializeAuth();
  }

  private async initializeAuth(): Promise<void> {
    if (this.authService === null) return;
    this.authState = await this.authService.restore();
    if (this.authState === 'authenticated') await this.initialize();
  }

  private async login(phone: string, password: string): Promise<void> {
    if (this.authService === null) return;
    await this.authService.login(phone, password);
    this.authState = 'authenticated';
    await this.initialize();
  }

  private async logout(): Promise<void> {
    if (this.authService !== null) await this.authService.logout();
    if (this.widgetCacheService !== null) await this.widgetCacheService.clear();
    this.store.resetUserData();
    this.selectedIndex = 0;
    this.authState = 'unauthenticated';
  }

  private async changeTheme(mode: ThemeMode): Promise<void> {
    if (this.themeService === null) return;
    await this.themeService.save(mode);
    this.themeMode = mode;
  }

  private async initialize(): Promise<void> {
    // 首屏数据不能被 ReminderAgent 阻塞。部分模拟器会让提醒系统调用长时间不返回，
    // 因此先完成业务数据加载，让首页及时可用，再在后台恢复提醒配置与校准。
    if (this.widgetCacheService !== null) await this.widgetCacheService.markPossiblyStale();
    await this.store.load();
    if (this.store.errorMessage.length > 0) return;
    this.store.setReminderSync(async (today: TodayData) => this.reconcileReminder(today));
    if (this.reminderService !== null) {
      try {
        const snapshot: ReminderSnapshot = await this.reminderService.initialize(this.store.today);
        this.applyReminderSnapshot(snapshot);
      } catch (error) {
        this.applyReminderFailure(error, '提醒初始化失败');
      }
    }
  }

  private async reconcileReminder(today: TodayData): Promise<void> {
    if (this.reminderService === null) return;
    try {
      const snapshot: ReminderSnapshot = await this.reminderService.reconcile(today, false);
      this.applyReminderSnapshot(snapshot);
    } catch (error) {
      this.applyReminderFailure(error, '提醒校准失败');
    }
  }

  private async saveReminder(config: ReminderConfig): Promise<void> {
    if (this.reminderService === null) return;
    try {
      const snapshot: ReminderSnapshot = await this.reminderService.saveConfig(config, this.store.today);
      this.applyReminderSnapshot(snapshot);
    } catch (error) {
      this.applyReminderFailure(error, '提醒保存失败');
    }
  }

  private applyReminderFailure(error: Object, prefix: string): void {
    const message: string = error instanceof Error ? error.message : '未知系统错误';
    this.store.reminderState = {
      status: 'publish_failed', scheduledCount: 0, expectedCount: 0,
      message: `${prefix}：${message}`
    };
  }

  private applyReminderSnapshot(snapshot: ReminderSnapshot): void {
    this.store.reminderConfig = snapshot.config;
    this.store.reminderState = snapshot.state;
  }

  private selectTab(index: number): void {
    animateTo({ duration: 420, curve: Curve.Friction }, () => this.selectedIndex = index);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%').height('100%').backgroundColor($r('app.color.page_background'))
        .expandSafeArea(
          [SafeAreaType.SYSTEM, SafeAreaType.CUTOUT],
          [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]
        )

      if (this.authState === 'checking') {
        Column({ space: 12 }) {
          LoadingProgress().width(42).height(42).color('#2C8196')
          Text('正在检查登录状态').fontSize(14).fontColor('#607D90')
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      } else if (this.authState === 'unauthenticated' || this.authState === 'expired') {
        LoginView({
          loginExpired: this.authState === 'expired',
          onLogin: (phone: string, password: string) => this.login(phone, password)
        })
      } else if (this.store.isLoading || this.store.errorMessage.length > 0) {
        Column() {
          StatusPanel({
            loading: this.store.isLoading,
            message: this.store.errorMessage,
            onRetry: () => {
              this.store.clearError();
              this.initialize();
            }
          })
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      } else {
        if (this.selectedIndex === 0) {
          HomeView({ store: this.store })
        } else if (this.selectedIndex === 1) {
          StatsView({ store: this.store })
        } else {
          SettingsView({
            store: this.store,
            onSaveReminder: (config: ReminderConfig) => this.saveReminder(config),
            onLogout: () => this.logout(),
            themeMode: this.themeMode,
            onThemeChange: (mode: ThemeMode) => this.changeTheme(mode)
          })
        }

        GlassNavigation({ selectedIndex: this.selectedIndex, onSelect: (index: number) => this.selectTab(index) })
          .margin({ bottom: 22 })
      }
    }.width('100%').height('100%')
  }
}
