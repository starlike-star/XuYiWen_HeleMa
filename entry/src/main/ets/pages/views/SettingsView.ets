import { ReminderConfig } from '../../models/WaterModels';
import { WaterStore } from '../../store/WaterStore';
import { ThemeMode } from '../../services/ThemeService';

@Component
export struct SettingsView {
  @ObjectLink store: WaterStore;
  onSaveReminder: (config: ReminderConfig) => Promise<void> = async (_config: ReminderConfig): Promise<void> => {};
  onLogout: () => Promise<void> = async (): Promise<void> => {};
  @Prop themeMode: ThemeMode = 'system';
  onThemeChange: (mode: ThemeMode) => Promise<void> = async (_mode: ThemeMode): Promise<void> => {};
  @State private targetValue: number = 8;
  @State private reminderEnabled: boolean = false;
  @State private startHour: number = 9;
  @State private endHour: number = 21;
  @State private intervalMinutes: number = 120;
  @State private reminderError: string = '';
  @State private reminderSaving: boolean = false;

  aboutToAppear(): void {
    this.syncDisplayedValues();
  }

  private syncDisplayedValues(): void {
    this.targetValue = this.store.settings.dailyTarget;
    this.reminderEnabled = this.store.reminderConfig.enabled;
    this.startHour = this.store.reminderConfig.startHour;
    this.endHour = this.store.reminderConfig.endHour;
    this.intervalMinutes = this.store.reminderConfig.intervalMinutes;
  }

  private clamp(value: number, minimum: number, maximum: number): number {
    return Math.max(minimum, Math.min(maximum, value));
  }

  private async saveTarget(): Promise<void> {
    await this.store.saveSettings(this.targetValue);
    this.targetValue = this.store.settings.dailyTarget;
  }

  private async saveReminder(): Promise<void> {
    const durationMinutes: number = Math.max(0, (this.endHour - this.startHour) * 60);
    const slotsPerDay: number = Math.floor(durationMinutes / this.intervalMinutes) + 1;
    if (this.endHour <= this.startHour) {
      this.reminderError = '结束时间需要晚于开始时间';
      return;
    }
    if (slotsPerDay * 2 > 30) {
      this.reminderError = '两天提醒超过 30 条，请增大间隔或缩短时间段';
      return;
    }
    this.reminderError = '';
    this.reminderSaving = true;
    try {
      await this.onSaveReminder({
        enabled: this.reminderEnabled,
        startHour: this.startHour,
        startMinute: 0,
        endHour: this.endHour,
        endMinute: 0,
        intervalMinutes: this.intervalMinutes,
        configVersion: this.store.reminderConfig.configVersion + 1
      });
      this.syncDisplayedValues();
    } finally {
      this.reminderSaving = false;
    }
  }

  @Builder
  private targetStepper() {
    Row({ space: 20 }) {
      Button('−')
        .width(56).height(56).borderRadius(28)
        .fontSize(20).backgroundColor('#DDF4FA').fontColor('#147BA8')
        .onClick(() => this.targetValue = this.clamp(this.targetValue - 1, 1, 30))
      Text(`${this.targetValue}`)
        .width(86).textAlign(TextAlign.Center)
        .fontSize(32).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_heading'))
      Button('+')
        .width(56).height(56).borderRadius(28)
        .fontSize(20).backgroundColor('#C9ECF8').fontColor('#0B7FB2')
        .onClick(() => this.targetValue = this.clamp(this.targetValue + 1, 1, 30))
    }.justifyContent(FlexAlign.Center).width('100%')
  }

  @Builder
  private startHourControl() {
    Column({ space: 10 }) {
      Text('开始时间').fontSize(12).fontColor('#718B9C')
      Text(`${this.startHour.toString().padStart(2, '0')}:00`)
        .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#173B52')
      Row({ space: 12 }) {
        Button('−').width(44).height(40).backgroundColor('#E4F3F7').fontColor('#28718F')
          .onClick(() => this.startHour = this.clamp(this.startHour - 1, 0, 23))
        Button('+').width(44).height(40).backgroundColor('#E4F3F7').fontColor('#28718F')
          .onClick(() => this.startHour = this.clamp(this.startHour + 1, 0, 23))
      }
    }
    .layoutWeight(1).height(118).justifyContent(FlexAlign.Center)
    .borderRadius(22).backgroundColor($r('app.color.surface_secondary'))
  }

  @Builder
  private endHourControl() {
    Column({ space: 10 }) {
      Text('结束时间').fontSize(12).fontColor('#718B9C')
      Text(`${this.endHour.toString().padStart(2, '0')}:00`)
        .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#173B52')
      Row({ space: 12 }) {
        Button('−').width(44).height(40).backgroundColor('#E4F3F7').fontColor('#28718F')
          .onClick(() => this.endHour = this.clamp(this.endHour - 1, 0, 23))
        Button('+').width(44).height(40).backgroundColor('#E4F3F7').fontColor('#28718F')
          .onClick(() => this.endHour = this.clamp(this.endHour + 1, 0, 23))
      }
    }
    .layoutWeight(1).height(118).justifyContent(FlexAlign.Center)
    .borderRadius(22).backgroundColor($r('app.color.surface_secondary'))
  }

  @Builder
  private intervalButton(minutes: number) {
    Button(`${minutes} 分钟`)
      .layoutWeight(1).height(44).fontSize(12).borderRadius(17)
      .fontColor(this.intervalMinutes === minutes ? '#FFFFFFFF' : '#37667D')
      .backgroundColor(this.intervalMinutes === minutes ? '#1BA5D2' : '#E2F3F7')
      .onClick(() => this.intervalMinutes = minutes)
  }

  @Builder
  private themeButton(mode: ThemeMode, label: string) {
    Button(label)
      .layoutWeight(1).height(44).borderRadius(17)
      .fontColor(this.themeMode === mode ? '#FFFFFFFF' : $r('app.color.text_secondary'))
      .backgroundColor(this.themeMode === mode ? $r('app.color.accent_primary') : $r('app.color.surface_secondary'))
      .onClick(() => this.onThemeChange(mode))
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 4 }) {
          Text('我的设置').fontSize(34).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          Text('让喝水节奏更适合你').fontSize(14).fontColor($r('app.color.text_secondary'))
        }.width('100%').alignItems(HorizontalAlign.Start)

        Column({ space: 18 }) {
          Column({ space: 4 }) {
            Text('每日目标').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_heading'))
            Text('只按打卡次数判断是否达标').fontSize(12).fontColor('#6F899A')
          }.width('100%').alignItems(HorizontalAlign.Start)
          this.targetStepper()
          Text(`每天 ${this.targetValue} 次`)
            .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#4D7187')
          Button(this.store.isSavingSettings ? '正在保存…' : '保存每日目标')
            .enabled(!this.store.isSavingSettings)
            .width('100%').height(52).borderRadius(24)
            .fontColor('#FFFFFFFF').fontWeight(FontWeight.Bold)
            .linearGradient({ angle: 100, colors: [['#36C9E2', 0], ['#168EC9', 1]] })
            .onClick(() => this.saveTarget())
        }
        .width('100%').padding(22).borderRadius(30).backgroundColor($r('app.color.surface_primary'))
        .border({ width: 1, color: $r('app.color.border_subtle') })

        Column({ space: 17 }) {
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Text('喝水提醒')
                .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_heading'))
                .maxLines(1)
              Text('! 目前无法开通推送 !')
                .fontSize(12).fontColor('#6F899A').maxLines(2)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Row() {
              Toggle({ type: ToggleType.Switch, isOn: this.reminderEnabled })
                .width(48).height(30)
                .selectedColor('#20A9D5')
                .onChange((enabled: boolean) => this.reminderEnabled = enabled)
            }
            .width(52).height(44)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
          }.width('100%').alignItems(VerticalAlign.Center)

          Row({ space: 12 }) {
            this.startHourControl()
            this.endHourControl()
          }.width('100%')

          Text('提醒间隔').width('100%').fontSize(12).fontColor('#718B9C')
          Row({ space: 8 }) {
            this.intervalButton(60)
            this.intervalButton(120)
            this.intervalButton(180)
          }.width('100%')

          if (this.reminderError.length > 0) {
            Text(this.reminderError).width('100%').fontSize(12).fontColor('#C84B58')
          }
          Text(this.store.reminderState.message)
            .width('100%').fontSize(12).maxLines(3)
            .fontColor(this.store.reminderState.status === 'enabled' ? '#168778' : '#6A8394')
          Button(this.reminderSaving ? '正在发布提醒…' : '保存并校准提醒')
            .enabled(!this.reminderSaving)
            .width('100%').height(50).borderRadius(23)
            .backgroundColor('#D5F0F7').fontColor('#176987').fontWeight(FontWeight.Bold)
            .onClick(() => this.saveReminder())
        }
        .width('100%').padding(22).borderRadius(30).backgroundColor($r('app.color.surface_primary'))
        .border({ width: 1, color: $r('app.color.border_subtle') })

        Column({ space: 5 }) {
          Text('服务连接').fontSize(12).fontColor('#738D9E')
          Text(this.store.activeBaseUrl)
            .width('100%').fontSize(13).fontColor('#315D76').maxLines(2)
          Text(`${this.store.dataMode} · ${this.store.databaseStatus}`)
            .fontSize(11).fontColor('#8299A7')
        }.width('100%').alignItems(HorizontalAlign.Start).padding(18)

        Column({ space: 12 }) {
          Text('外观').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_heading')).width('100%')
          Text('跟随系统可随设备外观自动切换').fontSize(12).fontColor($r('app.color.text_secondary')).width('100%')
          Row({ space: 8 }) {
            this.themeButton('system', '跟随系统')
            this.themeButton('light', '浅色')
            this.themeButton('dark', '深色')
          }.width('100%')
        }
        .width('100%').padding(22).borderRadius(30)
        .backgroundColor($r('app.color.surface_primary'))
        .border({ width: 1, color: $r('app.color.border_subtle') })

        Button('退出登录')
          .width('100%').height(48).borderRadius(22)
          .backgroundColor($r('app.color.danger_surface')).fontColor($r('app.color.danger_text'))
          .onClick(() => this.onLogout())
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 118 })
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }
}
