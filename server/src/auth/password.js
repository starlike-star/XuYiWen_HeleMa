import bcrypt from 'bcryptjs';

export async function hashPassword(password, rounds = 12) {
  return bcrypt.hash(password, Math.max(10, rounds));
}

export async function verifyPassword(password, passwordHash) {
  return bcrypt.compare(password, passwordHash);
}
