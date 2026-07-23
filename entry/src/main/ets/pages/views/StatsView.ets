import { RecordRow } from '../../components/common/RecordRow';
import { DayData, HistoryDay, StatsData, WaterRecord } from '../../models/WaterModels';
import { WaterStore } from '../../store/WaterStore';

@Component
export struct StatsView {
  @ObjectLink store: WaterStore;
  @State private periodIndex: number = 0;

  private data(): StatsData {
    return this.periodIndex === 0 ? this.store.weekStats : this.store.monthStats;
  }

  private dayLabel(date: string): string {
    return date.length >= 10 ? date.substring(8, 10) : date;
  }

  private monthLabel(): string {
    const anchor: string = this.store.monthStats.anchor;
    return anchor.length >= 7 ? `${anchor.substring(0, 4)} 年 ${anchor.substring(5, 7)} 月` : '本月';
  }

  private leadingDays(): number[] {
    const date: string = this.store.monthStats.range.startDate;
    if (date.length < 10) return [];
    const weekday: number = new Date(`${date}T00:00:00`).getDay();
    const count: number = (weekday + 6) % 7;
    return Array.from({ length: count }, (_value: undefined, index: number) => index);
  }

  private shiftMonth(offset: number): void {
    const anchor: string = this.store.monthStats.anchor.length > 0 ?
      this.store.monthStats.anchor : this.store.today.date;
    const year: number = Number(anchor.substring(0, 4));
    const month: number = Number(anchor.substring(5, 7)) - 1;
    const shifted: Date = new Date(year, month + offset, 1);
    const shiftedYear: number = shifted.getFullYear();
    const shiftedMonth: string = `${shifted.getMonth() + 1}`.padStart(2, '0');
    this.store.loadMonth(`${shiftedYear}-${shiftedMonth}-01`);
  }

  private requestDelete(recordId: number): void {
    AlertDialog.show({
      title: '删除这条喝水记录？',
      message: '删除后会重新计算当天进度和连续达标天数。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#D94E5D',
        action: () => this.store.deleteRecord(recordId)
      }
    });
  }

  @Builder
  private summaryCard(label: string, value: string, accent: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(24).fontWeight(FontWeight.Bold).fontColor(accent)
      Text(label).fontSize(11).fontColor('#6C8799')
    }
    .layoutWeight(1)
    .height(78)
    .justifyContent(FlexAlign.Center)
    .borderRadius(22)
    .backgroundColor($r('app.color.surface_primary'))
    .border({ width: 1, color: '#E8FFFFFF' })
    .shadow({ radius: 14, color: '#120B648A', offsetY: 5 })
  }

  @Builder
  private weekChart() {
    Column({ space: 16 }) {
      Row() {
        Text('本周饮水次数').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_heading'))
        Blank()
        Text('周一至周日').fontSize(12).fontColor('#758E9E')
      }.width('100%')
      Row() {
        ForEach(this.store.weekStats.days, (day: HistoryDay) => {
          Column({ space: 7 }) {
            Stack({ alignContent: Alignment.Bottom }) {
              Column().width(20).height(112).borderRadius(10).backgroundColor('#E5EFF4')
              Column()
                .width(20)
                .height(Math.max(7, 112 * Math.min(day.count / Math.max(day.target, 1), 1)))
                .borderRadius(10)
                .linearGradient({ angle: 180, colors: [['#4DDCE4', 0], ['#169ED8', 0.55], ['#0874BC', 1]] })
            }.height(112)
            Text(`${day.count}`).fontSize(12).fontWeight(FontWeight.Medium).fontColor('#315D76')
            Text(this.dayLabel(day.date)).fontSize(10).fontColor('#7A94A4')
          }.layoutWeight(1)
        }, (day: HistoryDay) => day.date)
      }.width('100%').alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .padding(20)
    .borderRadius(28)
    .backgroundColor($r('app.color.surface_primary'))
    .border({ width: 1, color: '#E8FFFFFF' })
  }

  @Builder
  private monthCalendar() {
    Column({ space: 14 }) {
      Row() {
        Button('‹').width(42).height(42).backgroundColor('#DDF5FB').fontColor('#177BA9')
          .onClick(() => this.shiftMonth(-1))
        Blank()
        Text(this.monthLabel()).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_heading'))
        Blank()
        Button('›').width(42).height(42).backgroundColor('#DDF5FB').fontColor('#177BA9')
          .onClick(() => this.shiftMonth(1))
      }.width('100%')
      Row() {
        ForEach(['一', '二', '三', '四', '五', '六', '日'], (label: string) => {
          Text(label).layoutWeight(1).textAlign(TextAlign.Center).fontSize(11).fontColor('#718B9C')
        })
      }.width('100%')
      Grid() {
        ForEach(this.leadingDays(), (blankIndex: number) => {
          GridItem() { Column().height(47) }
        }, (blankIndex: number) => `${blankIndex}`)
        ForEach(this.store.monthStats.days, (day: HistoryDay) => {
          GridItem() {
            Column({ space: 3 }) {
              Text(`${Number(this.dayLabel(day.date))}`)
                .fontSize(14)
                .fontWeight(day.date === this.store.today.date ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(day.completed ? '#FFFFFFFF' : '#274C62')
              Text(day.completed ? '达标' : `${day.count}/${day.target}`)
                .fontSize(8)
                .fontColor(day.completed ? '#EFFFFFFF' : '#7A94A4')
            }
            .width(42)
            .height(44)
            .justifyContent(FlexAlign.Center)
            .borderRadius(15)
            .backgroundColor(day.completed ? '#1AA8D7' :
              (day.date === this.store.today.date ? '#DDF5FB' : Color.Transparent))
            .border({ width: day.date === this.store.today.date ? 1 : 0, color: '#77CFEA' })
            .onClick(() => this.store.selectDay(day.date))
          }
        }, (day: HistoryDay) => day.date)
      }
      .columnsTemplate('repeat(7, 1fr)')
      .columnsGap(2)
      .rowsGap(4)
      .width('100%')
      .height(292)
    }
    .width('100%')
    .padding(18)
    .borderRadius(28)
    .backgroundColor($r('app.color.surface_primary'))
    .border({ width: 1, color: '#E8FFFFFF' })
  }

  @Builder
  private dayDetail(day: DayData) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text(day.date).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#15384F')
          Text(`${day.count}/${day.target} 次 · 共 ${day.totalAmountMl} ml`)
            .fontSize(13).fontColor('#678397')
        }.alignItems(HorizontalAlign.Start)
        Blank()
        Button('×').width(42).height(42).backgroundColor('#DDF3F8').fontColor('#315D76')
          .onClick(() => this.store.closeSelectedDay())
      }.width('100%')
      if (day.records.length === 0) {
        Text('这一天还没有喝水记录').height(90).fontSize(14).fontColor('#7A94A4')
      } else {
        List() {
          ForEach(day.records, (record: WaterRecord, index: number) => {
            RecordRow({ record: record, sequence: day.count - index, onDelete: (id: number) => this.requestDelete(id) })
          }, (record: WaterRecord) => `${record.id}`)
        }.height(Math.min(260, day.records.length * 64))
      }
      Text('向左滑动记录可删除').fontSize(11).fontColor('#8AA0AE')
    }
    .width('92%')
    .padding(20)
    .borderRadius(30)
    .backgroundColor($r('app.color.surface_primary'))
    .backgroundBlurStyle(BlurStyle.Thick)
    .border({ width: 1.4, color: '#FFFFFFFF' })
    .shadow({ radius: 28, color: '#35075B7D', offsetY: 10 })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Scroll() {
        Column({ space: 18 }) {
          Row() {
            Column({ space: 4 }) {
              Text('饮水统计').fontSize(34).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
              Text('看见每一次坚持').fontSize(14).fontColor($r('app.color.text_secondary'))
            }.alignItems(HorizontalAlign.Start)
            Blank()
            Row() {
              Button('周').layoutWeight(1).height(40).backgroundColor(this.periodIndex === 0 ? '#A8E7F8' : Color.Transparent)
                .fontColor('#176487').onClick(() => this.periodIndex = 0)
              Button('月').layoutWeight(1).height(40).backgroundColor(this.periodIndex === 1 ? '#A8E7F8' : Color.Transparent)
                .fontColor('#176487').onClick(() => this.periodIndex = 1)
            }
            .width(118).height(44).padding(2).borderRadius(22)
            .backgroundColor('#AFFFFFFF').backgroundBlurStyle(BlurStyle.Thick)
            .border({ width: 1, color: '#FFFFFFFF' })
          }.width('100%')

          Row({ space: 9 }) {
            this.summaryCard('总次数', `${this.data().summary.totalCount}`, '#087EB8')
            this.summaryCard('达标天', `${this.data().summary.completedDays}`, '#149A91')
          }.width('100%')
          Row({ space: 9 }) {
            this.summaryCard('当前连续', `${this.data().summary.currentStreak} 天`, '#6756B8')
            this.summaryCard('最长连续', `${this.data().summary.longestStreak} 天`, '#D37C25')
          }.width('100%')

          if (this.periodIndex === 0) { this.weekChart() } else { this.monthCalendar() }
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 24, bottom: 118 })
      }.width('100%').height('100%').scrollBar(BarState.Off)

      if (this.store.selectedDay !== null) {
        Column()
          .width('100%').height('100%').backgroundColor('#26092B3D')
          .onClick(() => this.store.closeSelectedDay())
        this.dayDetail(this.store.selectedDay)
      }
    }.width('100%').height('100%')
  }
}
