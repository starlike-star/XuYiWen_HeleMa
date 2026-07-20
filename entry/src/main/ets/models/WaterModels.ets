export interface ApiErrorBody {
  code: string;
  message: string;
}

export interface ApiEnvelope<T> {
  success: boolean;
  data?: T;
  error?: ApiErrorBody;
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

export interface TodayData {
  date: string;
  count: number;
  target: number;
  completed: boolean;
  records: WaterRecord[];
  created?: boolean;
}

export interface HistoryDay {
  date: string;
  count: number;
  target: number;
  completed: boolean;
}

export interface HistoryData {
  days: HistoryDay[];
}
