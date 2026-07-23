import { DateTime } from 'luxon';
import { DEFAULT_WATER_TARGET } from './config.js';

export class StreakService {
  targetForDate(date, goals) {
    let target = DEFAULT_WATER_TARGET;
    for (const goal of goals) {
      if (goal.effectiveDate > date) break;
      target = Number(goal.targetCount);
    }
    return target;
  }

  calculate(aggregates, goals, todayDate, timeZone) {
    if (aggregates.length === 0) {
      return { current: 0, longest: 0 };
    }

    const counts = new Map(aggregates.map((row) => [row.date, Number(row.count)]));
    const firstDate = aggregates[0].date;
    const start = DateTime.fromISO(firstDate, { zone: timeZone }).startOf('day');
    const today = DateTime.fromISO(todayDate, { zone: timeZone }).startOf('day');
    let longest = 0;
    let running = 0;

    for (let day = start; day <= today; day = day.plus({ days: 1 })) {
      const date = day.toISODate();
      const completed = (counts.get(date) || 0) >= this.targetForDate(date, goals);
      running = completed ? running + 1 : 0;
      longest = Math.max(longest, running);
    }

    const todayCompleted = (counts.get(todayDate) || 0) >= this.targetForDate(todayDate, goals);
    let cursor = todayCompleted ? today : today.minus({ days: 1 });
    let current = 0;
    while (cursor >= start) {
      const date = cursor.toISODate();
      if ((counts.get(date) || 0) < this.targetForDate(date, goals)) break;
      current += 1;
      cursor = cursor.minus({ days: 1 });
    }

    return { current, longest };
  }
}
