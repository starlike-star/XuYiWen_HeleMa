import { LiquidWaterCup } from '../../components/animations/LiquidWaterCup';
import { WaterRecord } from '../../models/WaterModels';
import { WaterStore } from '../../store/WaterStore';

@Component
export struct HomeView {
  @ObjectLink store: WaterStore;
  onOpenHistory: () => void = () => {};

  @State private actionScale: number = 1;
  @State private pressedToolIndex: number = -1;

  private dateLabel(): string {
    if (this.store.today.date.length < 10) return '今天';
    return `${this.store.today.date.substring(5, 7)}月${this.store.today.date.substring(8, 10)}日`;
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

  private remainingLabel(): string {
    return this.store.today.completed ? '今日已达标' : `还差 ${this.store.remaining()} 次`;
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

  private toolTouch(index: number, event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.pressedToolIndex = index;
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.pressedToolIndex = -1;
    }
  }

  @Builder
  private glassTool(index: number, icon: string, action: () => void) {
    Button() {
      Text(icon)
        .fontSize(icon === '…' ? 25 : 22)
        .fontWeight(FontWeight.Medium)
        .fontColor('#163E57')
        .translate({ y: icon === '…' ? -2 : 0 })
    }
    .width(48)
    .height(48)
    .padding(0)
    .borderRadius(24)
    .backgroundColor('#C9FFFFFF')
    .border({ width: 1, color: '#FFFFFFFF' })
    .backgroundBlurStyle(BlurStyle.Thin)
    .shadow({ radius: 12, color: '#200C678F', offsetY: 6 })
    .scale({
      x: this.pressedToolIndex === index ? 0.93 : 1,
      y: this.pressedToolIndex === index ? 0.93 : 1
    })
    .animation({ duration: this.pressedToolIndex === index ? 100 : 340, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => this.toolTouch(index, event))
    .onClick(action)
  }

  @Builder
  private statCard(label: string, value: string) {
    Column({ space: 3 }) {
      Text(label)
        .fontSize(11)
        .fontColor('#688398')
      Text(value)
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
        Row() {
          Column({ space: 5 }) {
            Text(`${this.dateLabel()} · 星期一`)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#58758A')
            Text('喝了吗')
              .fontSize(36)
              .fontWeight(FontWeight.Bold)
              .fontColor('#071D2F')
            Text('你的身体70%都是由水组成的')
              .fontSize(15)
              .fontColor('#58758A')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Row({ space: 8 }) {
            this.glassTool(0, '▦', () => this.onOpenHistory())
            this.glassTool(1, '…', () => this.store.load())
          }
          .width(104)
          .height(50)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')

        Row() {
          Text(`今日已完成 ${this.store.today.count} 次`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#173950')
          Blank()
          Text('目标 8 次')
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
              Text('/ 8')
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
          ForEach([0, 1, 2, 3, 4, 5, 6, 7], (index: number) => {
            Circle()
              .width(index < this.store.today.count ? 14 : 10)
              .height(index < this.store.today.count ? 14 : 10)
              .fill(index < this.store.today.count ? '#22B3E2' : '#D7E5EC')
              .animation({ duration: 280, curve: Curve.Friction })
          })
        }
        .height(20)
        .justifyContent(FlexAlign.Center)
        .width('100%')

        Row({ space: 10 }) {
          this.statCard('最近一次', this.recentLabel())
          this.statCard('距离目标', this.remainingLabel())
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
            .padding({ left: 20, right: 20 })
          }
        }
        .enabled(!this.store.isSubmitting)
        .stateEffect(false)
        .width('100%')
        .height(66)
        .padding(0)
        .borderRadius(33)
        .linearGradient({
          angle: 96,
          colors: [['#B930B7E8', 0], ['#A84CC9E5', 0.52], ['#A563D7D6', 1]]
        })
        .border({ width: 1.6, color: '#F0FFFFFF' })
        .backgroundBlurStyle(BlurStyle.Thick)
        .shadow({ radius: 20, color: '#300A78A2', offsetY: 9 })
        .scale({ x: this.actionScale, y: this.actionScale })
        .margin({ top: 24, bottom: 12 })
        .onTouch((event: TouchEvent) => this.touchScale(event))
        .onClick(() => this.store.checkIn())

      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 22, bottom: 118 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
