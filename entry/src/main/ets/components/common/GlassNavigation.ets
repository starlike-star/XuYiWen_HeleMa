@Component
export struct GlassNavigation {
  @Prop selectedIndex: number = 0;
  onSelect: (index: number) => void = () => {};
  @State private pressedIndex: number = -1;

  private handleTouch(index: number, event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.pressedIndex = index;
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.pressedIndex = -1;
    }
  }

  @Builder
  private navItem(index: number, icon: string, label: string) {
    Button() {
      Row({ space: 10 }) {
        Text(icon)
          .fontSize(icon === '◆' ? 18 : 23)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.selectedIndex === index ? '#087EB8' : '#526F82')
        Text(label)
          .fontSize(15)
          .fontWeight(this.selectedIndex === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.selectedIndex === index ? '#075B85' : '#526F82')
      }
      .justifyContent(FlexAlign.Center)
    }
    .stateEffect(false)
    .width('48%')
    .height(58)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .scale({
      x: this.pressedIndex === index ? 0.95 : 1,
      y: this.pressedIndex === index ? 0.95 : 1
    })
    .animation({ duration: this.pressedIndex === index ? 110 : 380, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => this.handleTouch(index, event))
    .onClick(() => this.onSelect(index))
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width('100%')
        .height(70)
        .borderRadius(35)
        .backgroundColor('#52FFFFFF')
        .border({ width: 1.4, color: '#E8FFFFFF' })
        .backgroundBlurStyle(BlurStyle.Thick)
        .shadow({ radius: 23, color: '#310A6289', offsetY: 11 })

      Row()
        .width('91%')
        .height(2)
        .borderRadius(1)
        .linearGradient({
          angle: 90,
          colors: [['#10FFFFFF', 0], ['#FFFFFFFF', 0.32], ['#92DFFFFF', 0.75], ['#10FFFFFF', 1]]
        })
        .position({ x: '4.5%', y: 4 })

      Row()
        .width('45%')
        .height(56)
        .borderRadius(28)
        .linearGradient({
          angle: 120,
          colors: [['#BFEAFCFF', 0], ['#79D6F5FF', 0.46], ['#55B7E9FF', 1]]
        })
        .backgroundBlurStyle(BlurStyle.Thick)
        .border({ width: 1.2, color: '#E8FFFFFF' })
        .shadow({ radius: 14, color: '#200870A0', offsetY: 5 })
        .translate({ x: this.selectedIndex === 0 ? -83 : 83 })
        .animation({ duration: 420, curve: Curve.Friction })

      Row() {
        this.navItem(0, '◆', '今日')
        this.navItem(1, '◷', '记录')
      }
      .justifyContent(FlexAlign.SpaceAround)
      .width('96%')
      .height(64)
    }
    .width('92%')
    .height(72)
  }
}
