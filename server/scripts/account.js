import { once } from 'node:events';
import { AuthService } from '../src/auth/authService.js';
import { normalizePhone } from '../src/auth/validation.js';
import { loadConfig } from '../src/config.js';
import { createRepository } from '../src/repositories/index.js';

const [command, ...args] = process.argv.slice(2);
const option = (name) => {
  const index = args.indexOf(`--${name}`);
  return index >= 0 ? args[index + 1] : undefined;
};

async function readPassword() {
  if (process.stdin.isTTY) {
    throw new Error('为避免密码出现在命令历史中，请通过标准输入传入密码（例如管道或受控终端输入）。');
  }
  let value = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => { value += chunk; });
  await once(process.stdin, 'end');
  return value.replace(/\r?\n$/, '');
}

const config = loadConfig();
if (config.dataMode !== 'mysql' || !config.dbConfigured) {
  throw new Error('账号管理脚本仅支持已配置 MySQL 的 DATA_MODE=mysql 环境。');
}
const repository = createRepository(config);
const auth = new AuthService(repository, config.auth);

try {
  if (command === 'create') {
    const phone = option('phone');
    const password = await readPassword();
    const user = await auth.createAccount(phone, password, option('nickname'));
    console.log(`账号已创建：id=${user.id} phone=${user.phone} nickname=${user.nickname}`);
  } else if (command === 'change-password') {
    const password = await readPassword();
    const user = await auth.changePassword(option('phone'), password);
    if (!user) throw new Error('账号不存在');
    console.log(`密码已修改并撤销全部会话：id=${user.id} phone=${user.phone}`);
  } else if (command === 'disable' || command === 'enable') {
    const phone = normalizePhone(option('phone'));
    if (!phone) throw new Error('手机号格式不正确');
    const user = await repository.setUserStatus(phone, command === 'enable' ? 'active' : 'disabled');
    if (!user) throw new Error('账号不存在');
    console.log(`账号状态已更新：id=${user.id} phone=${user.phone} status=${user.status}`);
  } else if (command === 'list') {
    const users = await repository.listUsers();
    console.table(users.map(({ id, phone, nickname, status, failedLoginCount, lockedUntil, lastLoginAt }) => ({
      id, phone, nickname, status, failedLoginCount, lockedUntil, lastLoginAt
    })));
  } else if (command === 'migrate-default') {
    const phone = normalizePhone(option('to-phone'));
    const legacyUserId = Number(option('legacy-user-id') || 1);
    if (!phone || !Number.isSafeInteger(legacyUserId) || legacyUserId < 1) {
      throw new Error('需要有效的 --to-phone 和可选 --legacy-user-id');
    }
    const result = await repository.migrateLegacyUserData(legacyUserId, phone);
    console.log(`默认用户数据迁移完成：legacyUserId=${result.legacyUserId} targetUserId=${result.targetUserId}`);
  } else {
    throw new Error(
      '用法：account create|change-password --phone <11位手机号> [--nickname <昵称>]；' +
      'account disable|enable|list；account migrate-default --to-phone <手机号> [--legacy-user-id 1]'
    );
  }
} finally {
  await repository.close();
}
