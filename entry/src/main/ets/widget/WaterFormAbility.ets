import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { WaterApi } from '../api/WaterApi';
import { AuthSessionService, AuthState } from '../services/AuthSessionService';
import {
  createWidgetSnapshot, EMPTY_WIDGET_SNAPSHOT, WidgetSnapshot
} from '../services/WidgetCacheService';

interface WaterCardMessage {
  msg?: string;
  actionName?: string;
}

export default class WaterFormAbility extends FormExtensionAbility {
  private checkInRunning: boolean = false;

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = String(want.parameters?.[formInfo.FormParam.IDENTITY_KEY] || '');
    this.loadAndUpdate(formId);
    return formBindingData.createFormBindingData(EMPTY_WIDGET_SNAPSHOT);
  }

  onUpdateForm(formId: string): void {
    this.loadAndUpdate(formId);
  }

  onFormEvent(formId: string, message: string): void {
    if (this.isCheckInMessage(message)) this.checkIn(formId);
  }

  async onRemoveForm(formId: string): Promise<void> {
    const store = await preferences.getPreferences(this.context, { name: 'widget_cache' });
    const ids: string[] = JSON.parse(String(await store.get('formIds', '[]'))) as string[];
    await store.put('formIds', JSON.stringify(ids.filter((id: string) => id !== formId)));
    await store.flush();
  }

  private async readSnapshot(): Promise<WidgetSnapshot> {
    const store = await preferences.getPreferences(this.context, { name: 'widget_cache' });
    return JSON.parse(String(await store.get('snapshot', JSON.stringify(EMPTY_WIDGET_SNAPSHOT)))) as WidgetSnapshot;
  }

  private async rememberFormId(formId: string): Promise<void> {
    if (formId.length === 0) return;
    const store = await preferences.getPreferences(this.context, { name: 'widget_cache' });
    const ids: string[] = JSON.parse(String(await store.get('formIds', '[]'))) as string[];
    if (!ids.includes(formId)) ids.push(formId);
    await store.put('formIds', JSON.stringify(ids));
    await store.flush();
  }

  private async loadAndUpdate(formId: string): Promise<void> {
    await this.rememberFormId(formId);
    try {
      await formProvider.updateForm(
        formId,
        formBindingData.createFormBindingData(await this.readSnapshot())
      );
    } catch (_) {
      // 桌面移除卡片或系统正在恢复时，等待下一次刷新。
    }
  }

  private isCheckInMessage(message: string): boolean {
    if (message === 'checkIn') return true;
    try {
      const event: WaterCardMessage = JSON.parse(message) as WaterCardMessage;
      return event.msg === 'checkIn' || event.actionName === 'checkIn';
    } catch (_) {
      return false;
    }
  }

  private async checkIn(formId: string): Promise<void> {
    if (this.checkInRunning) return;
    this.checkInRunning = true;
    const api: WaterApi = new WaterApi();
    const auth: AuthSessionService = new AuthSessionService(api);
    try {
      const state: AuthState = await auth.restore();
      if (state !== 'authenticated') {
        await this.writeAndRefresh(EMPTY_WIDGET_SNAPSHOT, formId);
        return;
      }
      const result = await api.checkIn();
      await this.writeAndRefresh(createWidgetSnapshot(result.today), formId);
    } catch (_) {
      if (auth.state === 'expired' || auth.state === 'unauthenticated') {
        await this.writeAndRefresh(EMPTY_WIDGET_SNAPSHOT, formId);
      } else {
        const snapshot: WidgetSnapshot = await this.readSnapshot();
        snapshot.possiblyStale = true;
        await this.writeAndRefresh(snapshot, formId);
      }
    } finally {
      this.checkInRunning = false;
    }
  }

  private async writeAndRefresh(snapshot: WidgetSnapshot, formId: string): Promise<void> {
    const store = await preferences.getPreferences(this.context, { name: 'widget_cache' });
    await store.put('snapshot', JSON.stringify(snapshot));
    await store.flush();
    try {
      await formProvider.updateForm(formId, formBindingData.createFormBindingData(snapshot));
    } catch (_) {
      // The form may have been removed while the background action was running.
    }
  }
}
