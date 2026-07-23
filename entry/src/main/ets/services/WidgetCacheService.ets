import { common } from '@kit.AbilityKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { preferences } from '@kit.ArkData';
import { TodayData } from '../models/WaterModels';

export interface WidgetSnapshot {
  loggedIn: boolean;
  count: number;
  target: number;
  percent: number;
  lastDrinkTime: string;
  updatedAt: string;
  possiblyStale: boolean;
}

export const EMPTY_WIDGET_SNAPSHOT: WidgetSnapshot = {
  loggedIn: false, count: 0, target: 0, percent: 0,
  lastDrinkTime: '--:--', updatedAt: '', possiblyStale: false
};

export function createWidgetSnapshot(today: TodayData): WidgetSnapshot {
  const last: string = today.records.length > 0 ? today.records[0].drankAt : '';
  return {
    loggedIn: true,
    count: today.count,
    target: today.target,
    percent: today.target > 0 ? Math.min(100, Math.round(today.count * 100 / today.target)) : 0,
    lastDrinkTime: last.length >= 16 ? last.substring(11, 16) : '--:--',
    updatedAt: currentTimeLabel(),
    possiblyStale: false
  };
}

function currentTimeLabel(): string {
  const date: Date = new Date();
  const hours: string = date.getHours().toString().padStart(2, '0');
  const minutes: string = date.getMinutes().toString().padStart(2, '0');
  return `${hours}:${minutes}`;
}

export class WidgetCacheService {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async update(today: TodayData): Promise<void> {
    await this.write(createWidgetSnapshot(today));
  }

  async markPossiblyStale(): Promise<void> {
    const snapshot: WidgetSnapshot = await this.read();
    if (!snapshot.loggedIn) return;
    snapshot.possiblyStale = true;
    await this.write(snapshot);
  }

  async clear(): Promise<void> {
    await this.write(EMPTY_WIDGET_SNAPSHOT);
  }

  private async read(): Promise<WidgetSnapshot> {
    const store = await preferences.getPreferences(this.context, { name: 'widget_cache' });
    return JSON.parse(String(await store.get('snapshot', JSON.stringify(EMPTY_WIDGET_SNAPSHOT)))) as WidgetSnapshot;
  }

  private async write(snapshot: WidgetSnapshot): Promise<void> {
    const store = await preferences.getPreferences(this.context, { name: 'widget_cache' });
    await store.put('snapshot', JSON.stringify(snapshot));
    await store.flush();
    const idsText: string = String(await store.get('formIds', '[]'));
    const ids: string[] = JSON.parse(idsText) as string[];
    for (let index: number = 0; index < ids.length; index++) {
      try {
        await formProvider.updateForm(ids[index], formBindingData.createFormBindingData(snapshot));
      } catch (_) {
        // 卡片可能已从桌面移除，后续 onRemoveForm 会清理 id。
      }
    }
  }
}
