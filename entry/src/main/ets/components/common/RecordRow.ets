import { WaterRecord } from '../../models/WaterModels';

@Component
export struct RecordRow {
  @Prop record: WaterRecord;
  @Prop sequence: number = 1;
  onDelete: (recordId: number) => void = () => {};

  private timeLabel(): string {
    return this.record.drankAt.length >= 16 ? this.record.drankAt.substring(11, 16) : '--:--';
  }

  @Builder
  private deleteAction() {
    Button('删除')
      .width(72)
      .height(54)
      .fontSize(14)
      .fontColor('#FFFFFFFF')
      .backgroundColor('#E45B68')
      .borderRadius(18)
      .onClick(() => this.onDelete(this.record.id))
  }

  build() {
    ListItem() {
      Row({ space: 13 }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle().width(38).height(38).fill('#DDF6FC').stroke('#FFFFFFFF').strokeWidth(1)
          Circle().width(11).height(11).fill('#20AFE0')
        }
        Column({ space: 3 }) {
          Text(this.timeLabel())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_heading'))
          Text(this.record.amountMl === null ? '完成一次补水' : `${this.record.amountMl} ml`)
            .fontSize(12)
            .fontColor('#7892A2')
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text(`#${this.sequence}`)
          .fontSize(12)
          .fontColor('#4D8EAC')
      }
      .width('100%')
      .height(62)
      .padding({ left: 4, right: 4 })
      .backgroundColor($r('app.color.surface_primary'))
    }
    .swipeAction({
      end: {
        builder: () => { this.deleteAction() },
        actionAreaDistance: 80
      },
      edgeEffect: SwipeEdgeEffect.Spring
    })
  }
}
