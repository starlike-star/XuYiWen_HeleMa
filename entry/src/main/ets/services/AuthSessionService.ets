import { WaterApi } from '../api/WaterApi';
import { AuthTokens, AuthUser } from '../models/WaterModels';
import { SecureSessionStore, StoredSession } from './SecureSessionStore';

export type AuthState = 'checking' | 'authenticated' | 'unauthenticated' | 'expired';

export class AuthSessionService {
  private api: WaterApi;
  private secureStore: SecureSessionStore = new SecureSessionStore();
  private refreshToken: string = '';
  private refreshPromise: Promise<boolean> | null = null;
  private stateListener: (state: AuthState) => void = (_state: AuthState) => {};

  state: AuthState = 'checking';
  user: AuthUser | null = null;

  constructor(api: WaterApi) {
    this.api = api;
    this.api.setRefreshHandler(() => this.tryRefresh());
  }

  setStateListener(listener: (state: AuthState) => void): void {
    this.stateListener = listener;
  }

  async restore(): Promise<AuthState> {
    this.state = 'checking';
    const stored: StoredSession | null = await this.secureStore.load();
    if (stored === null) {
      this.state = 'unauthenticated';
      this.stateListener(this.state);
      return this.state;
    }
    this.api.setAccessToken(stored.accessToken);
    this.refreshToken = stored.refreshToken;
    try {
      const me = await this.api.me();
      this.user = me.user;
      this.state = 'authenticated';
      this.stateListener(this.state);
    } catch (error) {
      if (!await this.tryRefresh()) {
        await this.clear('expired');
      }
    }
    return this.state;
  }

  async login(phone: string, password: string): Promise<void> {
    const tokens: AuthTokens = await this.api.login(phone, password);
    await this.applyTokens(tokens);
  }

  async tryRefresh(): Promise<boolean> {
    if (this.refreshPromise !== null) return this.refreshPromise;
    this.refreshPromise = this.performRefresh();
    const result: boolean = await this.refreshPromise;
    this.refreshPromise = null;
    if (!result) await this.clear('expired');
    return result;
  }

  private async performRefresh(): Promise<boolean> {
    if (this.refreshToken.length === 0) return false;
    try {
      const tokens: AuthTokens = await this.api.refresh(this.refreshToken);
      await this.applyTokens(tokens);
      return true;
    } catch (_) {
      return false;
    }
  }

  async logout(): Promise<void> {
    try {
      await this.api.logout();
    } catch (_) {
      // 本地退出必须成功；网络恢复后服务端会话仍会按过期时间失效。
    }
    await this.clear('unauthenticated');
  }

  private async applyTokens(tokens: AuthTokens): Promise<void> {
    this.api.setAccessToken(tokens.accessToken);
    this.refreshToken = tokens.refreshToken;
    this.user = tokens.user;
    this.state = 'authenticated';
    this.stateListener(this.state);
    await this.secureStore.save({ accessToken: tokens.accessToken, refreshToken: tokens.refreshToken });
  }

  private async clear(nextState: AuthState): Promise<void> {
    this.api.setAccessToken('');
    this.refreshToken = '';
    this.user = null;
    this.state = nextState;
    this.stateListener(this.state);
    await this.secureStore.clear();
  }
}
