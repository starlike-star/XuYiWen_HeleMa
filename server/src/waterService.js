import { DateTime } from 'luxon';
import { DEFAULT_AMOUNT_ML } from './config.js';
import { AppError } from './errors.js';
import { StreakService } from './streakService.js';
import { dayRangeUtc, localDay, parseLocalDate, toLocalIso, zoneOffsetFor } from './time.js';

export class WaterService {
  constructor(repository, config, clock = () => new Date(), streakService = new StreakService()) {
    this.repository = repository;
    this.config = config;
    this.clock = clock;
    this.streakService = streakService;
  }

  currentDay() {
    return localDay(this.clock(), this.config.timeZone).startOf('day');
  }

  async health() {
    return {
      service: 'up',
      dataMode: this.config.dataMode,
      database: await this.repository.health()
    };
  }

  mapRecord(record) {
    return {
      id: Number(record.id),
      amountMl: record.amountMl === null ? null : Number(record.amountMl),
      drankAt: toLocalIso(record.drankAt, this.config.timeZone)
    };
  }

  targetForDate(date, goals) {
    return this.streakService.targetForDate(date, goals);
  }

  async day(userId, date) {
    const day = parseLocalDate(date, this.config.timeZone);
    if (!day.isValid || day.toISODate() !== date) {
      throw new AppError(400, 'INVALID_DATE', 'date 必须是有效的 YYYY-MM-DD 日期。');
    }
    const range = dayRangeUtc(day);
    const [records, goals] = await Promise.all([
      this.repository.listByRange(userId, range.start, range.end),
      this.repository.getGoalsThroughDate(userId, date)
    ]);
    const target = this.targetForDate(date, goals);
    const mappedRecords = records.map((record) => this.mapRecord(record)).reverse();
    return {
      date,
      count: records.length,
      target,
      completed: records.length >= target,
      totalAmountMl: mappedRecords.reduce((total, record) => total + (record.amountMl || 0), 0),
      records: mappedRecords
    };
  }

  async today(userId) {
    return this.day(userId, this.currentDay().toISODate());
  }

  async settings(userId) {
    const day = this.currentDay();
    const date = day.toISODate();
    const goals = await this.repository.getGoalsThroughDate(userId, date);
    const latestGoal = goals.length > 0 ? goals[goals.length - 1] : null;
    return {
      dailyTarget: this.targetForDate(date, goals),
      goalEffectiveDate: latestGoal?.effectiveDate || null
    };
  }

  async updateSettings(userId, dailyTarget) {
    const effectiveDate = this.currentDay().toISODate();
    await this.repository.updateDailyTarget(userId, effectiveDate, dailyTarget);
    return {
      settings: {
        dailyTarget,
        goalEffectiveDate: effectiveDate
      },
      today: await this.today(userId)
    };
  }

  async checkIn(userId, idempotencyKey) {
    const result = await this.repository.create({
      userId,
      amountMl: DEFAULT_AMOUNT_ML,
      drankAt: this.clock(),
      idempotencyKey
    });
    return {
      created: result.created,
      idempotentReplay: !result.created,
      recordId: Number(result.record.id),
      today: await this.today(userId)
    };
  }

  async deleteRecord(userId, recordId) {
    const record = await this.repository.deleteById(userId, recordId);
    if (!record) {
      throw new AppError(404, 'RECORD_NOT_FOUND', '打卡记录不存在或已被删除。');
    }
    const affectedDate = DateTime.fromJSDate(new Date(record.drankAt), { zone: 'utc' })
      .setZone(this.config.timeZone)
      .toISODate();
    return {
      deletedRecordId: Number(record.id),
      affectedDate,
      day: await this.day(userId, affectedDate)
    };
  }

  async history(userId, days) {
    const today = this.currentDay();
    const firstDay = today.minus({ days: days - 1 });
    return { days: await this.daysBetween(userId, firstDay, today) };
  }

  async daysBetween(userId, firstDay, lastDay) {
    const end = lastDay.plus({ days: 1 });
    const offset = zoneOffsetFor(firstDay);
    const [aggregates, goals] = await Promise.all([
      this.repository.aggregateByLocalDate(
        userId,
        firstDay.toUTC().toJSDate(),
        end.toUTC().toJSDate(),
        this.config.timeZone,
        offset
      ),
      this.repository.getGoalsThroughDate(userId, lastDay.toISODate())
    ]);
    const counts = new Map(aggregates.map((row) => [row.date, Number(row.count)]));
    const length = Math.floor(lastDay.diff(firstDay, 'days').days) + 1;
    return Array.from({ length }, (_, index) => {
      const date = firstDay.plus({ days: index }).toISODate();
      const count = counts.get(date) || 0;
      const target = this.targetForDate(date, goals);
      return { date, count, target, completed: count >= target };
    });
  }

  async stats(userId, period, anchorDate) {
    const anchor = anchorDate
      ? parseLocalDate(anchorDate, this.config.timeZone)
      : this.currentDay();
    if (!anchor.isValid || (anchorDate && anchor.toISODate() !== anchorDate)) {
      throw new AppError(400, 'INVALID_DATE', 'anchor 必须是有效的 YYYY-MM-DD 日期。');
    }
    let firstDay;
    let lastDay;
    if (period === 'week') {
      firstDay = anchor.minus({ days: anchor.weekday - 1 }).startOf('day');
      lastDay = firstDay.plus({ days: 6 });
    } else {
      firstDay = anchor.startOf('month');
      lastDay = anchor.endOf('month').startOf('day');
    }

    const days = await this.daysBetween(userId, firstDay, lastDay);
    const today = this.currentDay();
    const streakEnd = today.plus({ days: 1 }).toUTC().toJSDate();
    const offset = zoneOffsetFor(today);
    const [allAggregates, allGoals] = await Promise.all([
      this.repository.aggregateAllByLocalDate(userId, streakEnd, this.config.timeZone, offset),
      this.repository.getGoalsThroughDate(userId, today.toISODate())
    ]);
    const streaks = this.streakService.calculate(
      allAggregates,
      allGoals,
      today.toISODate(),
      this.config.timeZone
    );
    return {
      period,
      anchor: anchor.toISODate(),
      range: { startDate: firstDay.toISODate(), endDate: lastDay.toISODate() },
      todayDate: today.toISODate(),
      summary: {
        totalCount: days.reduce((total, day) => total + day.count, 0),
        completedDays: days.filter((day) => day.completed && day.date <= today.toISODate()).length,
        currentStreak: streaks.current,
        longestStreak: streaks.longest
      },
      days
    };
  }
}
