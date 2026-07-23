export const PHONE_PATTERN = /^1[3-9]\d{9}$/;

export function normalizePhone(phone) {
  if (typeof phone !== 'string' || !PHONE_PATTERN.test(phone)) return null;
  return `+86${phone}`;
}

export function isValidPassword(password) {
  return typeof password === 'string' &&
    password.length >= 8 &&
    password.length <= 64 &&
    /[A-Za-z]/.test(password) &&
    /\d/.test(password);
}
