import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { preferences } from '@kit.ArkData';
import { notificationManager } from '@kit.NotificationKit';
import {
  ReminderConfig, ReminderEntry, ReminderState, ReminderStatus, TodayData
} from '../models/WaterModels';

const PREFERENCES_NAME: string = 'water_reminder_preferences';
const CONFIG_KEY: string = 'reminder_config';
const ENTRIES_KEY: string = 'reminder_entries';
const MAX_REMINDERS: number = 30;

export interface ReminderSnapshot {
  config: ReminderConfig;
  state: ReminderState;
}

interface ReminderCleanupResult {
  beforeCount: number;
  afterCount: number;
  errorCode: number;
  errorMessage: string;
}

class ReminderPublishError extends Error {
  code: number;

  constructor(code: number, message: string) {
    super(message);
    this.code = code;
    this.name = 'ReminderPublishError';
  }
}

export class ReminderService {
  private context: common.UIAbilityContext;
  private store: preferences.Preferences | null = null;
  private config: ReminderConfig = {
    enabled: false, startHour: 9, startMinute: 0, endHour: 21, endMinute: 0,
    intervalMinutes: 120, configVersion: 1
  };
  private entries: ReminderEntry[] = [];

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async initialize(today: TodayData): Promise<ReminderSnapshot> {
    await this.load();
    return this.reconcile(today, false);
  }

  async saveConfig(config: ReminderConfig, today: TodayData): Promise<ReminderSnapshot> {
    await this.ensureStore();
    this.config = config;
    await this.store?.put(CONFIG_KEY, JSON.stringify(config));
    await this.store?.flush();
    return this.reconcile(today, config.enabled);
  }

  async reconcile(today: TodayData, requestAuthorization: boolean): Promise<ReminderSnapshot> {
    await this.ensureStore();
    if (!this.config.enabled) {
      await this.cancelEntries(this.entries);
      try {
        await reminderAgentManager.cancelAllReminders();
      } catch (_error) {
        // 关闭提醒时仍会清空本地索引，下次启用时再次与系统对账。
      }
      this.entries = [];
      await this.saveEntries();
      return this.snapshot('disabled', 0, 0, '提醒未开启');
    }

    let notificationEnabled: boolean = false;
    try {
      notificationEnabled = await notificationManager.isNotificationEnabled();
      if (!notificationEnabled && requestAuthorization) {
        await notificationManager.requestEnableNotification(this.context);
        notificationEnabled = await notificationManager.isNotificationEnabled();
      }
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      if (businessError.code === 201) {
        return this.snapshot('permission_required', this.entries.length, 0, '需要提醒发布权限');
      }
      return this.snapshot('publish_failed', this.entries.length, 0, '无法检查系统通知权限');
    }
    if (!notificationEnabled) {
      return this.snapshot('system_notification_disabled', this.entries.length, 0, '请在系统设置中开启通知');
    }

    const desired: ReminderEntry[] = this.generateDesiredSlots(today.completed);
    if (desired.length > MAX_REMINDERS) {
      return this.snapshot('publish_failed', this.entries.length, desired.length,
        '两天提醒超过 30 条，请调整时间段或间隔');
    }

    const systemSnapshot: ReminderSnapshot | null = await this.alignWithSystem(desired);
    if (systemSnapshot !== null) return systemSnapshot;

    const existingKeys: Set<string> = new Set(this.entries.map((entry: ReminderEntry) => entry.slotKey));
    let failed: number = 0;
    let failureCode: number = 0;
    let failureMessage: string = '';
    for (const slot of desired) {
      if (existingKeys.has(slot.slotKey)) continue;
      try {
        const reminderId: number = await reminderAgentManager.publishReminder(this.requestFor(slot));
        this.entries.push({
          reminderId,
          scheduledAt: slot.scheduledAt,
          slotKey: slot.slotKey,
          configVersion: this.config.configVersion
        });
        existingKeys.add(slot.slotKey);
        await this.saveEntries();
      } catch (error) {
        const businessError: BusinessError = error as BusinessError;
        if (businessError.code === 201) {
          return this.snapshot('permission_required', this.entries.length, desired.length, '需要提醒发布权限');
        }
        if (businessError.code === 1700001) {
          return this.snapshot('system_notification_disabled', this.entries.length, desired.length, '系统通知已关闭');
        }
        if (businessError.code === 1700002) {
          return this.recoverFromCapacityLimit(desired);
        }
        failureCode = businessError.code;
        failureMessage = businessError.message;
        failed += 1;
        break;
      }
    }

    let systemCount: number = this.entries.length;
    try {
      const valid: reminderAgentManager.ReminderInfo[] = await reminderAgentManager.getAllValidReminders();
      const desiredIds: Set<number> = new Set(desired.map((entry: ReminderEntry) => this.notificationId(entry.slotKey)));
      systemCount = valid.filter((info: reminderAgentManager.ReminderInfo) =>
        info.reminderReq.notificationId !== undefined && desiredIds.has(info.reminderReq.notificationId)
      ).length;
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      if (failureCode === 0) {
        failureCode = businessError.code;
        failureMessage = businessError.message;
      }
      failed += 1;
    }
    const scheduledCount: number = Math.min(this.entries.length, systemCount);
    if (scheduledCount === desired.length && failed === 0) {
      return this.snapshot('enabled', scheduledCount, desired.length, `已安排 ${scheduledCount} 个提醒`);
    }
    if (scheduledCount > 0) {
      return this.snapshot('partially_scheduled', scheduledCount, desired.length,
        `已安排 ${scheduledCount}/${desired.length} 个提醒${this.failureSuffix(failureCode, failureMessage)}`);
    }
    return this.snapshot('publish_failed', 0, desired.length,
      `提醒发布失败${this.failureSuffix(failureCode, failureMessage)}`);
  }

  getConfig(): ReminderConfig {
    return this.config;
  }

  private async load(): Promise<void> {
    await this.ensureStore();
    const configText: string = await this.store?.get(CONFIG_KEY, '') as string;
    const entriesText: string = await this.store?.get(ENTRIES_KEY, '') as string;
    if (configText.length > 0) {
      this.config = JSON.parse(configText) as ReminderConfig;
      if (![60, 120, 180].includes(this.config.intervalMinutes)) {
        this.config.intervalMinutes = this.config.intervalMinutes < 120 ? 60 : 120;
        this.config.configVersion += 1;
        await this.store?.put(CONFIG_KEY, JSON.stringify(this.config));
        await this.store?.flush();
      }
    }
    if (entriesText.length > 0) this.entries = JSON.parse(entriesText) as ReminderEntry[];
  }

  private async ensureStore(): Promise<void> {
    if (this.store === null) {
      this.store = await preferences.getPreferences(this.context, { name: PREFERENCES_NAME });
    }
  }

  private generateDesiredSlots(todayCompleted: boolean): ReminderEntry[] {
    const now: Date = new Date();
    const slots: ReminderEntry[] = [];
    for (let dayOffset: number = 0; dayOffset <= 1; dayOffset += 1) {
      const date: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + dayOffset, 0, 0, 0, 0);
      if (dayOffset === 0 && todayCompleted) continue;
      const start: number = this.config.startHour * 60 + this.config.startMinute;
      const end: number = this.config.endHour * 60 + this.config.endMinute;
      for (let minuteOfDay: number = start; minuteOfDay <= end; minuteOfDay += this.config.intervalMinutes) {
        const hour: number = Math.floor(minuteOfDay / 60);
        const minute: number = minuteOfDay % 60;
        const scheduled: Date = new Date(date.getFullYear(), date.getMonth(), date.getDate(), hour, minute, 0, 0);
        if (scheduled.getTime() <= now.getTime()) continue;
        const slotKey: string = this.slotKey(scheduled);
        slots.push({ reminderId: 0, scheduledAt: scheduled.toISOString(), slotKey,
          configVersion: this.config.configVersion });
      }
    }
    return slots;
  }

  private slotKey(date: Date): string {
    const year: string = `${date.getFullYear()}`;
    const month: string = `${date.getMonth() + 1}`.padStart(2, '0');
    const day: string = `${date.getDate()}`.padStart(2, '0');
    const hour: string = `${date.getHours()}`.padStart(2, '0');
    const minute: string = `${date.getMinutes()}`.padStart(2, '0');
    return `${year}-${month}-${day}T${hour}:${minute}`;
  }

  private requestFor(slot: ReminderEntry): reminderAgentManager.ReminderRequestCalendar {
    const date: Date = new Date(slot.scheduledAt);
    return {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: date.getFullYear(), month: date.getMonth() + 1, day: date.getDate(),
        hour: date.getHours(), minute: date.getMinutes(), second: 0
      },
      wantAgent: { pkgName: this.context.abilityInfo.bundleName, abilityName: 'EntryAbility' },
      title: '该喝水啦',
      content: '喝一杯水，让身体保持轻盈。',
      expiredContent: '这次喝水提醒已结束',
      notificationId: this.notificationId(slot.slotKey),
      groupId: 'helema_water_reminders',
      slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
      tapDismissed: true
    };
  }

  private notificationId(slotKey: string): number {
    let hash: number = 17;
    for (let index: number = 0; index < slotKey.length; index += 1) {
      hash = (hash * 31 + slotKey.charCodeAt(index)) & 0x7fffffff;
    }
    return hash;
  }

  private async alignWithSystem(desired: ReminderEntry[]): Promise<ReminderSnapshot | null> {
    let valid: reminderAgentManager.ReminderInfo[] = [];
    try {
      valid = await reminderAgentManager.getAllValidReminders();
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      if (businessError.code === 201) {
        return this.snapshot('permission_required', this.entries.length, desired.length, '缺少代理提醒发布权限（201）');
      }
      return this.snapshot('publish_failed', this.entries.length, desired.length,
        `无法读取系统提醒${this.failureSuffix(businessError.code, businessError.message)}`);
    }

    const desiredById: Map<number, ReminderEntry> = new Map();
    desired.forEach((entry: ReminderEntry) => desiredById.set(this.notificationId(entry.slotKey), entry));
    const retained: ReminderEntry[] = [];
    const retainedKeys: Set<string> = new Set();
    for (const info of valid) {
      const notificationId: number = info.reminderReq.notificationId === undefined ? -1 : info.reminderReq.notificationId;
      const desiredEntry: ReminderEntry | undefined = desiredById.get(notificationId);
      if (desiredEntry === undefined || retainedKeys.has(desiredEntry.slotKey)) {
        try {
          await reminderAgentManager.cancelReminder(info.reminderId);
        } catch (_error) {
          // 失效的系统提醒无需再次取消。
        }
        continue;
      }
      retained.push({
        reminderId: info.reminderId,
        scheduledAt: desiredEntry.scheduledAt,
        slotKey: desiredEntry.slotKey,
        configVersion: this.config.configVersion
      });
      retainedKeys.add(desiredEntry.slotKey);
    }
    this.entries = retained;
    await this.saveEntries();
    return null;
  }

  private async recoverFromCapacityLimit(desired: ReminderEntry[]): Promise<ReminderSnapshot> {
    const cleanup: ReminderCleanupResult = await this.cleanupSystemReminders();
    if (cleanup.errorCode !== 0) {
      if (cleanup.errorCode === 201) {
        return this.snapshot('permission_required', 0, desired.length, '清理旧提醒时缺少代理提醒权限（201）');
      }
      return this.snapshot('publish_failed', 0, desired.length,
        `旧提醒清理失败${this.failureSuffix(cleanup.errorCode, cleanup.errorMessage)}`);
    }
    if (cleanup.afterCount > 0) {
      return this.snapshot('publish_failed', 0, desired.length,
        `系统提醒未清空：包 ${this.context.abilityInfo.bundleName}，清理前 ${cleanup.beforeCount} 条，清理后仍有 ${cleanup.afterCount} 条，计划 ${desired.length} 条`);
    }

    for (const slot of desired) {
      try {
        const reminderId: number = await this.publishAfterCleanup(slot);
        this.entries.push({
          reminderId,
          scheduledAt: slot.scheduledAt,
          slotKey: slot.slotKey,
          configVersion: this.config.configVersion
        });
        await this.saveEntries();
      } catch (error) {
        const businessError: BusinessError = error as BusinessError;
        if (businessError.code === 201) {
          return this.snapshot('permission_required', this.entries.length, desired.length, '需要代理提醒发布权限（201）');
        }
        if (businessError.code === 1700001) {
          return this.snapshot('system_notification_disabled', this.entries.length, desired.length, '系统通知已关闭');
        }
        const status: ReminderStatus = this.entries.length > 0 ? 'partially_scheduled' : 'publish_failed';
        const prefix: string = this.entries.length > 0
          ? `已重新安排 ${this.entries.length}/${desired.length} 个提醒`
          : '清理旧提醒后重新发布仍失败';
        return this.snapshot(status, this.entries.length, desired.length,
          `${prefix}${this.failureSuffix(businessError.code, businessError.message)}；包 ${this.context.abilityInfo.bundleName}，清理前 ${cleanup.beforeCount}，清理后 ${cleanup.afterCount}，计划 ${desired.length}`);
      }
    }

    return this.snapshot('enabled', this.entries.length, desired.length,
      `已清理旧提醒并重新安排 ${this.entries.length} 个提醒`);
  }

  private async cleanupSystemReminders(): Promise<ReminderCleanupResult> {
    let beforeCount: number = -1;
    try {
      beforeCount = (await reminderAgentManager.getAllValidReminders()).length;
      // 此 API 只取消当前应用发布的代理提醒，不影响其他应用。
      await reminderAgentManager.cancelAllReminders();
      this.entries = [];
      await this.saveEntries();

      let remaining: reminderAgentManager.ReminderInfo[] = [];
      for (let attempt: number = 0; attempt < 6; attempt += 1) {
        await this.delay(400);
        remaining = await reminderAgentManager.getAllValidReminders();
        if (remaining.length === 0) {
          // 系统列表清空后再给配额数据库一点释放时间。
          await this.delay(800);
          remaining = await reminderAgentManager.getAllValidReminders();
          if (remaining.length === 0) break;
        }
        for (const info of remaining) {
          try {
            await reminderAgentManager.cancelReminder(info.reminderId);
          } catch (_error) {
            // 下一轮会重新枚举并确认是否仍然存在。
          }
        }
      }
      if (remaining.length > 0) {
        await this.delay(500);
        remaining = await reminderAgentManager.getAllValidReminders();
      }
      return { beforeCount, afterCount: remaining.length, errorCode: 0, errorMessage: '' };
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      return {
        beforeCount,
        afterCount: -1,
        errorCode: businessError.code,
        errorMessage: businessError.message
      };
    }
  }

  private async publishAfterCleanup(slot: ReminderEntry): Promise<number> {
    try {
      return await reminderAgentManager.publishReminder(this.requestFor(slot));
    } catch (error) {
      let businessError: BusinessError = error as BusinessError;
      if (businessError.code !== 1700002) {
        throw new ReminderPublishError(businessError.code, businessError.message);
      }

      // 模拟器的公开列表可能已经归零，但内部配额账本仍在异步释放。
      // 只在明确收到容量错误时分段等待，避免普通保存流程产生额外延迟。
      const retryDelays: number[] = [2000, 4000, 6000];
      for (let attempt: number = 0; attempt < retryDelays.length; attempt += 1) {
        await this.delay(retryDelays[attempt]);
        try {
          await reminderAgentManager.cancelAllReminders();
          const valid: reminderAgentManager.ReminderInfo[] =
            await reminderAgentManager.getAllValidReminders();
          for (const info of valid) {
            try {
              await reminderAgentManager.cancelReminder(info.reminderId);
            } catch (_error) {
              // 下一轮继续核对；不把已不存在的提醒视为恢复失败。
            }
          }
          return await reminderAgentManager.publishReminder(this.requestFor(slot));
        } catch (retryError) {
          businessError = retryError as BusinessError;
          if (businessError.code !== 1700002) {
            throw new ReminderPublishError(businessError.code, businessError.message);
          }
        }
      }
      throw new ReminderPublishError(businessError.code, businessError.message);
    }
  }

  private delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, milliseconds);
    });
  }

  private failureSuffix(code: number, message: string): string {
    if (code === 0) return '，请稍后重试';
    if (code === 401) return '：请求参数无效（401）';
    if (code === 1700002) {
      return '：当前应用提醒列表已清空，但系统内部配额仍拒绝第一条提醒（1700002）';
    }
    if (code === 1700004) return '：系统未识别当前应用包（1700004）';
    const detail: string = message.length > 0 ? `，${message}` : '';
    return `（错误码 ${code}${detail}）`;
  }

  private async cancelEntries(entries: ReminderEntry[]): Promise<void> {
    for (const entry of entries) {
      try {
        await reminderAgentManager.cancelReminder(entry.reminderId);
      } catch (_error) {
        // 已从系统消失的提醒视为取消成功。
      }
    }
  }

  private async saveEntries(): Promise<void> {
    await this.ensureStore();
    await this.store?.put(ENTRIES_KEY, JSON.stringify(this.entries));
    await this.store?.flush();
  }

  private snapshot(status: ReminderStatus, scheduledCount: number,
    expectedCount: number, message: string): ReminderSnapshot {
    return {
      config: this.config,
      state: { status, scheduledCount, expectedCount, message }
    };
  }
}
