@Component
struct SplashDropMark {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private draw(): void {
    const ctx: CanvasRenderingContext2D = this.context;
    ctx.clearRect(0, 0, 86, 98);
    const gradient: CanvasGradient = ctx.createLinearGradient(18, 10, 70, 88);
    gradient.addColorStop(0, '#FF52DDE9');
    gradient.addColorStop(0.5, '#FF1DB8E2');
    gradient.addColorStop(1, '#FF087CC4');
    ctx.beginPath();
    ctx.moveTo(43, 6);
    ctx.bezierCurveTo(38, 18, 16, 39, 16, 60);
    ctx.bezierCurveTo(16, 78, 28, 90, 43, 90);
    ctx.bezierCurveTo(58, 90, 70, 78, 70, 60);
    ctx.bezierCurveTo(70, 39, 48, 18, 43, 6);
    ctx.closePath();
    ctx.fillStyle = gradient;
    ctx.fill();
  }

  build() {
    Canvas(this.context)
      .width(86)
      .height(98)
      .onReady(() => this.draw())
  }
}

@Component
export struct SplashAnimation {
  onFinished: () => void = () => {};

  @State private dropY: number = -190;
  @State private rippleScale: number = 0.18;
  @State private rippleOpacity: number = 0;
  @State private copyOpacity: number = 0;

  aboutToAppear(): void {
    setTimeout(() => {
      animateTo({ duration: 760, curve: Curve.Friction }, () => {
        this.dropY = 0;
      });
    }, 100);
    setTimeout(() => {
      this.rippleOpacity = 0.64;
      animateTo({ duration: 900, curve: Curve.EaseOut }, () => {
        this.rippleScale = 1.25;
        this.rippleOpacity = 0;
      });
    }, 760);
    setTimeout(() => {
      animateTo({ duration: 560, curve: Curve.EaseOut }, () => {
        this.copyOpacity = 1;
      });
    }, 940);
    setTimeout(() => this.onFinished(), 2350);
  }

  build() {
    Column({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(176)
          .height(176)
          .fill(Color.Transparent)
          .stroke('#6CC2E8F4')
          .strokeWidth(2)
          .opacity(this.rippleOpacity)
          .scale({ x: this.rippleScale, y: this.rippleScale * 0.17 })
          .translate({ y: 56 })
        Circle()
          .width(118)
          .height(118)
          .fill(Color.Transparent)
          .stroke('#58A9DDF2')
          .strokeWidth(1.5)
          .opacity(this.rippleOpacity)
          .scale({ x: this.rippleScale, y: this.rippleScale * 0.17 })
          .translate({ y: 56 })
        SplashDropMark()
          .translate({ y: this.dropY - 20 })
      }
      .width(200)
      .height(180)

      Column({ space: 9 }) {
        Text('喝了吗')
          .fontSize(38)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .letterSpacing(2)
        Text('今天也要好好喝水')
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .letterSpacing(1)
      }
      .opacity(this.copyOpacity)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
