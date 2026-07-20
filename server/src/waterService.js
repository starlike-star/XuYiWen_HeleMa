import { DateTime } from 'luxon';
import { WATER_TARGET } from './config.js';
import { dayRangeUtc, localDay, toLocalIso } from './time.js';

export class WaterService {
  constructor(repository, config, clock = () => new Date()) {
    this.repository = repository;
    this.config = config;
    this.clock = clock;
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

  async today() {
    const day = localDay(this.clock(), this.config.timeZone);
    const range = dayRangeUtc(day);
    const records = await this.repository.listByRange(this.config.defaultUserId, range.start, range.end);
    return {
      date: day.toISODate(),
      count: records.length,
      target: WATER_TARGET,
      completed: records.length >= WATER_TARGET,
      records: records.map((record) => this.mapRecord(record)).reverse()
    };
  }

  async checkIn(amountMl, idempotencyKey) {
    const result = await this.repository.create({
      userId: this.config.defaultUserId,
      amountMl,
      drankAt: this.clock(),
      idempotencyKey
    });
    return { ...(await this.today()), created: result.created };
  }

  async history(days) {
    const today = localDay(this.clock(), this.config.timeZone).startOf('day');
    const firstDay = today.minus({ days: days - 1 });
    const end = today.plus({ days: 1 });
    const records = await this.repository.listByRange(
      this.config.defaultUserId,
      firstDay.toUTC().toJSDate(),
      end.toUTC().toJSDate()
    );
    const counts = new Map();
    for (const record of records) {
      const date = DateTime.fromJSDate(new Date(record.drankAt), { zone: 'utc' })
        .setZone(this.config.timeZone)
        .toISODate();
      counts.set(date, (counts.get(date) || 0) + 1);
    }
    return {
      days: Array.from({ length: days }, (_, index) => {
        const date = firstDay.plus({ days: index }).toISODate();
        const count = counts.get(date) || 0;
        return { date, count, target: WATER_TARGET, completed: count >= WATER_TARGET };
      })
    };
  }
}
