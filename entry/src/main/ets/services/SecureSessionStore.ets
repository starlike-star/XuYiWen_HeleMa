import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';

export interface StoredSession {
  accessToken: string;
  refreshToken: string;
}

const SESSION_ALIAS: string = 'helema.auth.session.v1';

export class SecureSessionStore {
  private encoder: util.TextEncoder = new util.TextEncoder();
  private decoder: util.TextDecoder = new util.TextDecoder();

  async save(session: StoredSession): Promise<void> {
    await this.clear();
    const attributes: asset.AssetMap = new Map();
    attributes.set(asset.Tag.ALIAS, this.encoder.encodeInto(SESSION_ALIAS));
    attributes.set(asset.Tag.SECRET, this.encoder.encodeInto(JSON.stringify(session)));
    await asset.add(attributes);
  }

  async load(): Promise<StoredSession | null> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.encoder.encodeInto(SESSION_ALIAS));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const results: asset.AssetMap[] = await asset.query(query);
      if (results.length === 0) return null;
      const secret: Uint8Array = results[0].get(asset.Tag.SECRET) as Uint8Array;
      return JSON.parse(this.decoder.decodeToString(secret)) as StoredSession;
    } catch (_) {
      return null;
    }
  }

  async clear(): Promise<void> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.encoder.encodeInto(SESSION_ALIAS));
    try {
      await asset.remove(query);
    } catch (_) {
      // 资产不存在时清理仍视为成功。
    }
  }
}
