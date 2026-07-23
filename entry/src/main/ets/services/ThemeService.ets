import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export type ThemeMode = 'system' | 'light' | 'dark';

export class ThemeService {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async restore(): Promise<ThemeMode> {
    const store = await preferences.getPreferences(this.context, { name: 'appearance' });
    const mode: ThemeMode = String(await store.get('themeMode', 'system')) as ThemeMode;
    this.apply(mode);
    return mode;
  }

  async save(mode: ThemeMode): Promise<void> {
    const store = await preferences.getPreferences(this.context, { name: 'appearance' });
    await store.put('themeMode', mode);
    await store.flush();
    this.apply(mode);
  }

  private apply(mode: ThemeMode): void {
    const colorMode: ConfigurationConstant.ColorMode = mode === 'light'
      ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
      : (mode === 'dark'
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    this.context.getApplicationContext().setColorMode(colorMode);
  }
}
