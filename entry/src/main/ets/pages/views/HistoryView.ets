import { HistoryDay, WaterRecord } from '../../models/WaterModels';
import { WaterStore } from '../../store/WaterStore';

@Component
export struct HistoryView {
  @ObjectLink store: WaterStore;

  private timeLabel(iso: string): string {
    return iso.length >= 16 ? iso.substring(11, 16) : '--:--';
  }

  private dayLabel(date: string): string {
    return date.length >= 10 ? `${date.substring(5, 7)}.${date.substring(8, 10)}` : date;
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 5 }) {
            Text('喝水记录')
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text('每杯水，都让健康更加离不开你')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width(82)
              .height(46)
              .borderRadius(23)
              .backgroundColor('#54FFFFFF')
              .backgroundBlurStyle(BlurStyle.Thick)
              .border({ width: 1.2, color: '#E8FFFFFF' })
              .shadow({ radius: 16, color: '#230A648B', offsetY: 7 })
            Row()
              .width(66)
              .height(1.5)
              .borderRadius(1)
              .backgroundColor('#EFFFFFFF')
              .position({ x: 8, y: 4 })
            Text(`${this.store.today.count} 次`)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#087EB8')
          }
          .width(82)
          .height(46)
        }
        .alignItems(VerticalAlign.Center)
        .width('100%')

        Column({ space: 16 }) {
          Row() {
            Text('最近 7 天')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_heading'))
            Blank()
            Text('目标 8 次 / 天')
              .fontSize(12)
              .fontColor('#738D9E')
          }
          .width('100%')

          Row() {
            ForEach(this.store.history, (day: HistoryDay) => {
              Column({ space: 7 }) {
                Stack({ alignContent: Alignment.Bottom }) {
                  Column()
                    .width(18)
                    .height(76)
                    .borderRadius(9)
                    .backgroundColor($r('app.color.chart_track'))
                  Column()
                    .width(18)
                    .height(Math.max(6, 76 * Math.min(day.count / 8, 1)))
                    .borderRadius(9)
                    .linearGradient({
                      angle: 180,
                      colors: [['#45D8E2', 0], ['#159DD7', 0.55], ['#0874BC', 1]]
                    })
                    .shadow({ radius: 7, color: '#24149BC9', offsetY: 3 })
                }
                .height(76)
                Text(`${day.count}`)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(day.completed ? '#087EB8' : '#567386')
                Text(this.dayLabel(day.date))
                  .fontSize(10)
                  .fontColor('#7A94A4')
              }
              .layoutWeight(1)
            }, (day: HistoryDay) => day.date)
          }
          .width('100%')
          .alignItems(VerticalAlign.Bottom)
        }
        .width('100%')
        .padding(20)
        .borderRadius(26)
        .backgroundColor($r('app.color.surface_primary'))
        .border({ width: 1, color: $r('app.color.border_subtle') })
        .shadow({ radius: 20, color: '#160B648A', offsetY: 8 })

        Column({ space: 4 }) {
          Row() {
            Text('今天喝了那么多水!')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_heading'))
            Blank()
            Text(`${this.store.records().length} 条记录`)
              .fontSize(12)
              .fontColor('#738D9E')
          }
          .width('100%')
          .margin({ bottom: 8 })

          if (this.store.records().length === 0) {
            Column({ space: 10 }) {
              Stack({ alignContent: Alignment.Center }) {
                Circle()
                  .width(48)
                  .height(48)
                  .fill('#E7F7FC')
                Text('＋')
                  .fontSize(24)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#2AA9D5')
              }
              Text('今天还没有喝水记录')
                .fontSize(14)
                .fontColor('#6F899A')
            }
            .height(132)
            .justifyContent(FlexAlign.Center)
            .width('100%')
          } else {
            ForEach(this.store.records(), (record: WaterRecord, index: number) => {
              Row({ space: 14 }) {
                Stack({ alignContent: Alignment.Center }) {
                  Circle()
                    .width(38)
                    .height(38)
                    .fill('#DDF6FC')
                    .stroke('#FFFFFFFF')
                    .strokeWidth(1)
                  Circle()
                    .width(12)
                    .height(12)
                    .fill('#20AFE0')
                }
                Column({ space: 3 }) {
                  Text(this.timeLabel(record.drankAt))
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_heading'))
                  Text(record.amountMl === null ? '完成一次补水' : `${record.amountMl} ml`)
                    .fontSize(12)
                    .fontColor('#7892A2')
                }
                .alignItems(HorizontalAlign.Start)
                Blank()
                Text(`#${this.store.today.count - index}`)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#4D8EAC')
              }
              .width('100%')
              .padding({ top: 13, bottom: 13 })
              .border({ width: { bottom: 0.5 }, color: '#B8DDE8EF' })
            }, (record: WaterRecord) => `${record.id}`)
          }
        }
        .width('100%')
        .padding(20)
        .borderRadius(26)
        .backgroundColor($r('app.color.surface_primary'))
        .border({ width: 1, color: $r('app.color.border_subtle') })
        .shadow({ radius: 20, color: '#160B648A', offsetY: 8 })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 112 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
