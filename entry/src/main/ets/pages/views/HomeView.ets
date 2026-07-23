import { LiquidWaterCup } from '../../components/animations/LiquidWaterCup';
import { WaterRecord } from '../../models/WaterModels';
import { WaterStore } from '../../store/WaterStore';

@Component
export struct HomeView {
  @ObjectLink store: WaterStore;

  @State private actionScale: number = 1;

  private dateLabel(): string {
    if (this.store.today.date.length < 10) return '今天';
    return `${this.store.today.date.substring(5, 7)}月${this.store.today.date.substring(8, 10)}日`;
  }

  private weekdayLabel(): string {
    if (this.store.today.date.length < 10) return '';
    const year: number = Number(this.store.today.date.substring(0, 4));
    const month: number = Number(this.store.today.date.substring(5, 7));
    const day: number = Number(this.store.today.date.substring(8, 10));
    const weekdays: string[] = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    // 使用服务端返回的年月日计算星期；UTC 仅用于避免设备时区改变日期组件。
    const weekday: number = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
    return weekdays[weekday];
  }

  private recentRecord(): WaterRecord | undefined {
    const records: WaterRecord[] = this.store.records();
    return records.length > 0 ? records[0] : undefined;
  }

  private recentLabel(): string {
    const record: WaterRecord | undefined = this.recentRecord();
    if (record === undefined || record.drankAt.length < 16) return '还没有记录';
    return record.drankAt.substring(11, 16);
  }

  private touchScale(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      animateTo({ duration: 110, curve: Curve.EaseOut }, () => {
        this.actionScale = 0.975;
      });
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      animateTo({ duration: 420, curve: Curve.Friction }, () => {
        this.actionScale = 1;
      });
    }
  }

  @Builder
  private recentStatCard() {
    Column({ space: 3 }) {
      Text('最近一次')
        .fontSize(11)
        .fontColor('#688398')
      Text(this.recentLabel())
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#14374F')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .height(58)
    .padding({ left: 14, right: 12 })
    .borderRadius(18)
    .backgroundColor('#E8FFFFFF')
    .border({ width: 1, color: '#D8E8F2F7' })
  }

  @Builder
  private remainingStatCard() {
    Column({ space: 3 }) {
      Text('距离目标')
        .fontSize(11)
        .fontColor('#688398')
      Text(this.store.today.completed
        ? '今日已达标'
        : `还差 ${Math.max(this.store.today.target - this.store.today.count, 0)} 次`)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#14374F')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .height(58)
    .padding({ left: 14, right: 12 })
    .borderRadius(18)
    .backgroundColor('#E8FFFFFF')
    .border({ width: 1, color: '#D8E8F2F7' })
  }

  build() {
    Scroll() {
      Column() {
        Column({ space: 5 }) {
          Text(`${this.dateLabel()} · ${this.weekdayLabel()}`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#58758A')
          Text('喝了吗')
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('不要等口渴了才想起喝水')
            .fontSize(15)
            .fontColor('#58758A')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Row() {
          Text(`今日已完成 ${this.store.today.count} 次`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#173950')
          Blank()
          Text(`目标 ${this.store.today.target} 次`)
            .fontSize(14)
            .fontColor('#637E91')
        }
        .width('100%')
        .height(44)
        .padding({ left: 15, right: 15 })
        .borderRadius(16)
        .backgroundColor('#E6FFFFFF')
        .border({ width: 1, color: '#F2FFFFFF' })
        .shadow({ radius: 18, color: '#160B648A', offsetY: 7 })
        .margin({ top: 26 })

        Stack({ alignContent: Alignment.Center }) {
          LiquidWaterCup({
            progress: this.store.progress(),
            feedbackToken: this.store.feedbackToken,
            celebrationToken: this.store.celebrationToken
          })

          Column({ space: 3 }) {
            Row({ space: 6 }) {
              Text(`${this.store.today.count}`)
                .fontSize(52)
                .fontWeight(FontWeight.Bold)
                .fontColor('#082A43')
              Text(`/ ${this.store.today.target}`)
                .fontSize(25)
                .fontWeight(FontWeight.Medium)
                .fontColor('#345C78')
                .margin({ top: 18 })
            }
            Text(this.store.today.completed ? '今日目标已完成' : `今日进度 ${Math.round(this.store.progress() * 100)}%`)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#164A69')
              .margin({ top: 46 })
          }
          .translate({ y: -5 })
        }
        .width('100%')
        .height(330)
        .margin({ top: 4 })

        Row({ space: 12 }) {
          ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], (index: number) => {
            Circle()
              .width(index < Math.round(this.store.progress() * 10) ? 14 : 10)
              .height(index < Math.round(this.store.progress() * 10) ? 14 : 10)
              .fill(index < Math.round(this.store.progress() * 10) ? '#22B3E2' : '#D7E5EC')
              .animation({ duration: 280, curve: Curve.Friction })
          })
        }
        .height(20)
        .justifyContent(FlexAlign.Center)
        .width('100%')

        Row({ space: 10 }) {
          this.recentStatCard()
          this.remainingStatCard()
        }
        .width('100%')
        .margin({ top: 18 })

        if (this.store.feedbackText.length > 0) {
          Row({ space: 7 }) {
            Circle()
              .width(8)
              .height(8)
              .fill('#20B8D8')
            Text(this.store.feedbackText)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#075F8D')
          }
          .padding({ left: 17, right: 17, top: 9, bottom: 9 })
          .borderRadius(18)
          .backgroundColor('#DDFBFFFF')
          .border({ width: 1, color: '#F2FFFFFF' })
          .transition(TransitionEffect.OPACITY)
          .margin({ top: 12 })
        }

        Button() {
          Stack({ alignContent: Alignment.Center }) {
            Row({ space: 13 }) {
              Stack({ alignContent: Alignment.Center }) {
                Circle()
                  .width(38)
                  .height(38)
                  .fill('#DEFFFFFF')
                  .stroke('#FFFFFFFF')
                  .strokeWidth(1)
                Text('+')
                  .fontSize(27)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#0A81BC')
              }
              Column({ space: 1 }) {
                Text(this.store.isSubmitting ? '正在记录…' : '喝了一杯')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFFFF')
                Text('记录一次饮水')
                  .fontSize(11)
                  .fontColor('#E9FAFFFF')
              }
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: 22, right: 18 })
          }
        }
        .enabled(!this.store.isSubmitting)
        .stateEffect(false).width('100%').height(66).padding(0).borderRadius(33)
        .linearGradient({ angle: 96, colors: [['#B930B7E8', 0], ['#A84CC9E5', 0.52], ['#A563D7D6', 1]] })
        .border({ width: 1.6, color: '#F0FFFFFF' }).backgroundBlurStyle(BlurStyle.Thick)
        .shadow({ radius: 20, color: '#300A78A2', offsetY: 9 })
        .scale({ x: this.actionScale, y: this.actionScale })
        .onTouch((event: TouchEvent) => this.touchScale(event))
        .onClick(() => this.store.checkIn())
        .width('100%').margin({ top: 24, bottom: 12 })

        if (this.store.undoVisible) {
          Row() {
            Text('已记录一次饮水').fontSize(13).fontColor('#315D76')
            Blank()
            Button('撤销').height(38).fontSize(13).fontWeight(FontWeight.Bold)
              .fontColor('#087EB8').backgroundColor(Color.Transparent)
              .onClick(() => this.store.undoLastCheckIn())
          }
          .width('100%').height(50).padding({ left: 16, right: 8 }).borderRadius(22)
          .backgroundColor('#EFFFFFFF').backgroundBlurStyle(BlurStyle.Thick)
          .border({ width: 1, color: '#FFFFFFFF' })
        }

      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 22, bottom: 118 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
