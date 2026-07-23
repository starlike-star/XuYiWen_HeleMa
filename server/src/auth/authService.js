import { AppError } from '../errors.js';
import { hashPassword, verifyPassword } from './password.js';
import { isValidPassword, normalizePhone } from './validation.js';
import {
  createAccessToken, createRefreshToken, hashToken, refreshSessionId, verifyAccessToken
} from './tokens.js';

const INVALID_CREDENTIALS = '手机号或密码不正确';
const DUMMY_HASH = '$2b$12$D4G5f18o7aMMfwasBL7a7eYGGtF3tXPHOBkM4d0eOEnu3bEJG0yva';

export class AuthService {
  constructor(repository, config, clock = () => new Date()) {
    this.repository = repository;
    this.config = config;
    this.clock = clock;
  }

  async login(phone, password) {
    const normalizedPhone = normalizePhone(phone);
    if (!normalizedPhone || !isValidPassword(password)) {
      throw new AppError(401, 'INVALID_CREDENTIALS', INVALID_CREDENTIALS);
    }
    const now = this.clock();
    const user = await this.repository.findUserByPhone(normalizedPhone);
    const passwordMatches = await verifyPassword(password, user?.passwordHash || DUMMY_HASH);
    if (!user || !passwordMatches) {
      if (user) {
        const lockUntil = user.failedLoginCount + 1 >= this.config.loginFailureLimit
          ? new Date(now.getTime() + this.config.loginLockSeconds * 1000)
          : null;
        await this.repository.recordLoginFailure(user.id, lockUntil);
      }
      throw new AppError(401, 'INVALID_CREDENTIALS', INVALID_CREDENTIALS);
    }
    if (user.status !== 'active') {
      throw new AppError(403, 'ACCOUNT_DISABLED', '账号已停用，请联系账号管理员。');
    }
    if (user.lockedUntil && new Date(user.lockedUntil) > now) {
      throw new AppError(423, 'ACCOUNT_LOCKED', '登录失败次数过多，请 15 分钟后重试。');
    }
    await this.repository.recordLoginSuccess(user.id, now);
    return this.issueSession(user, now);
  }

  async issueSession(user, now = this.clock()) {
    const expiresAt = new Date(now.getTime() + this.config.refreshTokenTtlSeconds * 1000);
    const sessionId = await this.repository.createSession(user.id, expiresAt);
    const refreshToken = createRefreshToken(sessionId);
    await this.repository.setSessionTokenHash(sessionId, hashToken(refreshToken));
    return {
      accessToken: createAccessToken({
        userId: user.id, sessionId, secret: this.config.accessTokenSecret,
        expiresInSeconds: this.config.accessTokenTtlSeconds, now
      }),
      refreshToken,
      accessTokenExpiresIn: this.config.accessTokenTtlSeconds,
      refreshTokenExpiresIn: this.config.refreshTokenTtlSeconds,
      user: this.publicUser(user)
    };
  }

  async authenticate(accessToken) {
    const claims = verifyAccessToken(accessToken, this.config.accessTokenSecret, this.clock());
    if (!claims) throw new AppError(401, 'AUTHENTICATION_REQUIRED', '登录已过期，请重新登录。');
    const session = await this.repository.findSessionById(claims.sessionId);
    const user = await this.repository.findUserById(claims.userId);
    if (!session || session.userId !== claims.userId || session.revokedAt ||
        new Date(session.expiresAt) <= this.clock() || !user || user.status !== 'active') {
      throw new AppError(401, 'AUTHENTICATION_REQUIRED', '登录已过期，请重新登录。');
    }
    return { userId: user.id, sessionId: session.id, user: this.publicUser(user) };
  }

  async refresh(refreshToken) {
    const sessionId = refreshSessionId(refreshToken);
    const session = sessionId ? await this.repository.findSessionById(sessionId) : null;
    const now = this.clock();
    if (!session || session.revokedAt || new Date(session.expiresAt) <= now ||
        !session.refreshTokenHash || hashToken(refreshToken) !== session.refreshTokenHash) {
      throw new AppError(401, 'REFRESH_TOKEN_INVALID', '登录已过期，请重新登录。');
    }
    const user = await this.repository.findUserById(session.userId);
    if (!user || user.status !== 'active') {
      await this.repository.revokeSession(session.id, now);
      throw new AppError(401, 'REFRESH_TOKEN_INVALID', '登录已过期，请重新登录。');
    }
    await this.repository.revokeSession(session.id, now);
    return this.issueSession(user, now);
  }

  async logout(sessionId) {
    await this.repository.revokeSession(sessionId, this.clock());
  }

  publicUser(user) {
    return { id: Number(user.id), phone: user.phone, nickname: user.nickname, status: user.status };
  }

  async createAccount(phone, password, nickname) {
    const normalizedPhone = normalizePhone(phone);
    if (!normalizedPhone) throw new AppError(400, 'INVALID_PHONE', '手机号格式不正确。');
    if (!isValidPassword(password)) {
      throw new AppError(400, 'INVALID_PASSWORD', '密码必须为 8～64 位，且至少包含一个字母和一个数字。');
    }
    const passwordHash = await hashPassword(password, this.config.bcryptRounds);
    return this.repository.createUser({
      phone: normalizedPhone, passwordHash, nickname: nickname || `用户${phone.slice(-4)}`
    });
  }

  async changePassword(phone, password) {
    const normalizedPhone = normalizePhone(phone);
    if (!normalizedPhone) throw new AppError(400, 'INVALID_PHONE', '手机号格式不正确。');
    if (!isValidPassword(password)) {
      throw new AppError(400, 'INVALID_PASSWORD', '密码必须为 8～64 位，且至少包含一个字母和一个数字。');
    }
    const passwordHash = await hashPassword(password, this.config.bcryptRounds);
    return this.repository.changePassword(normalizedPhone, passwordHash, this.clock());
  }
}
