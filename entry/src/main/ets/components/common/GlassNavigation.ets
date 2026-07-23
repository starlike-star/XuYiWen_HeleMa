@Component
export struct GlassNavigation {
  @Prop selectedIndex: number = 0;
  onSelect: (index: number) => void = () => {};
  @State private pressedIndex: number = -1;

  private handleTouch(index: number, event: TouchEvent): void {
    if (event.type === TouchType.Down) this.pressedIndex = index;
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) this.pressedIndex = -1;
  }

  @Builder
  private navItem(index: number, icon: string, label: string) {
    Button() {
      Column({ space: 2 }) {
        Text(icon).fontSize(19).fontWeight(FontWeight.Medium)
          .fontColor(this.selectedIndex === index ? '#087EB8' : '#526F82')
        Text(label).fontSize(11)
          .fontWeight(this.selectedIndex === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.selectedIndex === index ? '#075B85' : '#526F82')
      }.justifyContent(FlexAlign.Center)
    }
    .stateEffect(false).layoutWeight(1).height(58).padding(0).backgroundColor(Color.Transparent)
    .scale({ x: this.pressedIndex === index ? 0.94 : 1, y: this.pressedIndex === index ? 0.94 : 1 })
    .animation({ duration: this.pressedIndex === index ? 110 : 380, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => this.handleTouch(index, event))
    .onClick(() => this.onSelect(index))
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row().width('100%').height(70).borderRadius(35)
        .backgroundColor($r('app.color.surface_primary')).border({ width: 1.4, color: $r('app.color.border_subtle') })
        .backgroundBlurStyle(BlurStyle.Thick).shadow({ radius: 23, color: '#310A6289', offsetY: 11 })
      Row().width('91%').height(2).borderRadius(1)
        .linearGradient({ angle: 90, colors: [['#10FFFFFF', 0], ['#FFFFFFFF', 0.32], ['#92DFFFFF', 0.75], ['#10FFFFFF', 1]] })
        .position({ x: '4.5%', y: 4 })
      Row().width('30%').height(56).borderRadius(28)
        .linearGradient({ angle: 120, colors: [['#CBEFFFFF', 0], ['#85DCF6FF', 0.5], ['#60BCEAFF', 1]] })
        .backgroundBlurStyle(BlurStyle.Thick).border({ width: 1.2, color: '#E8FFFFFF' })
        .shadow({ radius: 14, color: '#200870A0', offsetY: 5 })
        .translate({ x: (this.selectedIndex - 1) * 104 })
        .animation({ duration: 420, curve: Curve.Friction })
      Row() {
        this.navItem(0, '◆', '今日')
        this.navItem(1, '▦', '统计')
        this.navItem(2, '●', '我的')
      }.width('96%').height(64)
    }.width('92%').height(72)
  }
}
