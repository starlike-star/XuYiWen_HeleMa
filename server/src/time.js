import { DateTime } from 'luxon';

export function localDay(now, timeZone) {
  return DateTime.fromJSDate(now, { zone: 'utc' }).setZone(timeZone);
}

export function dayRangeUtc(day) {
  return {
    start: day.startOf('day').toUTC().toJSDate(),
    end: day.plus({ days: 1 }).startOf('day').toUTC().toJSDate()
  };
}

export function toLocalIso(value, timeZone) {
  return DateTime.fromJSDate(new Date(value), { zone: 'utc' })
    .setZone(timeZone)
    .toISO({ suppressMilliseconds: true });
}
