@Component
struct LiquidLoadingOrb {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private timer: number = -1;
  private fillProgress: number = 0.06;
  private waveOffset: number = 0;

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      this.fillProgress += 0.007;
      if (this.fillProgress > 1.12) this.fillProgress = 0.06;
      this.waveOffset += 0.14;
      this.draw();
    }, 32);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) clearInterval(this.timer);
  }

  private draw(): void {
    const ctx: CanvasRenderingContext2D = this.context;
    const center: number = 34;
    const outerRadius: number = 27;
    const innerRadius: number = 23;
    const progress: number = Math.min(this.fillProgress, 1);
    const bottom: number = center + innerRadius;
    const waterY: number = bottom - progress * innerRadius * 2;

    ctx.clearRect(0, 0, 68, 68);
    ctx.save();
    ctx.beginPath();
    ctx.arc(center, center, innerRadius, 0, Math.PI * 2);
    ctx.clip();

    ctx.fillStyle = '#FFF8FCFE';
    ctx.fillRect(8, 8, 52, 52);

    const waterGradient: CanvasGradient = ctx.createLinearGradient(0, waterY, 0, bottom);
    waterGradient.addColorStop(0, '#FF42CFEA');
    waterGradient.addColorStop(0.55, '#FF1DA7DF');
    waterGradient.addColorStop(1, '#FF0877C5');
    ctx.fillStyle = waterGradient;
    ctx.beginPath();
    ctx.moveTo(8, waterY);
    for (let x: number = 8; x <= 60; x += 3) {
      const y: number = waterY + Math.sin((x / 8) + this.waveOffset) * 2;
      ctx.lineTo(x, y);
    }
    ctx.lineTo(60, 64);
    ctx.lineTo(8, 64);
    ctx.closePath();
    ctx.fill();

    if (progress > 0.32) {
      const bubbleTravel: number = (this.waveOffset * 5) % Math.max(8, bottom - waterY - 5);
      const bubbleY: number = bottom - 5 - bubbleTravel;
      if (bubbleY > waterY + 4) {
        ctx.beginPath();
        ctx.arc(27, bubbleY, 2.2, 0, Math.PI * 2);
        ctx.fillStyle = '#70FFFFFF';
        ctx.fill();
      }
    }
    ctx.restore();

    ctx.beginPath();
    ctx.arc(center, center, outerRadius, 0, Math.PI * 2);
    ctx.lineWidth = 2.6;
    ctx.strokeStyle = '#FF1598D3';
    ctx.stroke();
  }

  build() {
    Canvas(this.context)
      .width(68)
      .height(68)
      .onReady(() => this.draw())
  }
}

@Component
export struct StatusPanel {
  @Prop loading: boolean = false;
  @Prop message: string = '';
  onRetry: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      if (this.loading) {
        LiquidLoadingOrb()
        Text('正在汇集今天的水滴…')
          .fontSize(15)
          .fontColor('#55768B')
      } else {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(48)
            .height(48)
            .fill('#DFF5FB')
          Text('!')
            .fontSize(25)
            .fontWeight(FontWeight.Bold)
            .fontColor('#148CBD')
        }
        Text(this.message)
          .fontSize(15)
          .fontColor('#365B72')
          .textAlign(TextAlign.Center)
          .lineHeight(23)
          .maxLines(4)
        Button('重新连接')
          .height(44)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#087BB5')
          .backgroundColor('#70FFFFFF')
          .border({ width: 1.2, color: '#E8FFFFFF' })
          .backgroundBlurStyle(BlurStyle.Thick)
          .shadow({ radius: 16, color: '#210A6E96', offsetY: 7 })
          .onClick(() => this.onRetry())
      }
    }
    .justifyContent(FlexAlign.Center)
    .width('88%')
    .padding(28)
    .borderRadius(28)
    .backgroundColor('#72FFFFFF')
    .border({ width: 1.2, color: '#E8FFFFFF' })
    .backgroundBlurStyle(BlurStyle.Thick)
    .shadow({ radius: 26, color: '#240B6489', offsetY: 12 })
  }
}
