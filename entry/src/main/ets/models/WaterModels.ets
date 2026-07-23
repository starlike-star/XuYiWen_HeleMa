export interface ApiErrorBody {
  code: string;
  message: string;
}

export interface ApiEnvelope<T> {
  success: boolean;
  data?: T;
  error?: ApiErrorBody;
}

export interface AuthUser {
  id: number;
  phone: string;
  nickname: string;
  status: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresIn: number;
  refreshTokenExpiresIn: number;
  user: AuthUser;
}

export interface MeData {
  user: AuthUser;
}

export interface LogoutData {
  loggedOut: boolean;
}

export interface DatabaseHealth {
  status: string;
  message: string;
}

export interface HealthData {
  service: string;
  dataMode: string;
  database: DatabaseHealth;
}

export interface WaterRecord {
  id: number;
  amountMl: number | null;
  drankAt: string;
}

export interface DayData {
  date: string;
  count: number;
  target: number;
  completed: boolean;
  totalAmountMl: number;
  records: WaterRecord[];
}

export type TodayData = DayData;

export interface HistoryDay {
  date: string;
  count: number;
  target: number;
  completed: boolean;
}

export interface HistoryData {
  days: HistoryDay[];
}

export interface WaterSettings {
  dailyTarget: number;
  goalEffectiveDate: string | null;
}

export interface UpdateSettingsData {
  settings: WaterSettings;
  today: TodayData;
}

export interface CheckInData {
  created: boolean;
  idempotentReplay: boolean;
  recordId: number;
  today: TodayData;
}

export interface DeleteRecordData {
  deletedRecordId: number;
  affectedDate: string;
  day: DayData;
}

export interface StatsRange {
  startDate: string;
  endDate: string;
}

export interface StatsSummary {
  totalCount: number;
  completedDays: number;
  currentStreak: number;
  longestStreak: number;
}

export interface StatsData {
  period: string;
  anchor: string;
  range: StatsRange;
  todayDate: string;
  summary: StatsSummary;
  days: HistoryDay[];
}

export type ReminderStatus = 'disabled' | 'enabled' | 'permission_required' |
  'system_notification_disabled' | 'publish_failed' | 'partially_scheduled';

export interface ReminderConfig {
  enabled: boolean;
  startHour: number;
  startMinute: number;
  endHour: number;
  endMinute: number;
  intervalMinutes: number;
  configVersion: number;
}

export interface ReminderEntry {
  reminderId: number;
  scheduledAt: string;
  slotKey: string;
  configVersion: number;
}

export interface ReminderState {
  status: ReminderStatus;
  scheduledCount: number;
  expectedCount: number;
  message: string;
}
