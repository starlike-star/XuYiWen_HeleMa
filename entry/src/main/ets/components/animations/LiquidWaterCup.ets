@Component
export struct LiquidWaterCup {
  @Prop progress: number = 0;
  @Prop feedbackToken: number = 0;
  @Prop celebrationToken: number = 0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private timer: number = -1;
  private displayProgress: number = 0;
  private waveOffset: number = 0;
  private splashEnergy: number = 0;
  private lastFeedbackToken: number = 0;
  private lastCelebrationToken: number = 0;
  @State private glowOpacity: number = 0.22;
  @State private vesselScale: number = 1;

  aboutToAppear(): void {
    this.lastFeedbackToken = this.feedbackToken;
    this.lastCelebrationToken = this.celebrationToken;
    this.timer = setInterval(() => {
      const difference: number = this.progress - this.displayProgress;
      this.displayProgress += Math.abs(difference) < 0.004 ? difference : difference * 0.075;
      this.waveOffset += 0.105;
      this.splashEnergy *= 0.93;

      if (this.feedbackToken !== this.lastFeedbackToken) {
        this.lastFeedbackToken = this.feedbackToken;
        this.splashEnergy = 1;
        animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
          this.vesselScale = 1.028;
          this.glowOpacity = 0.34;
        });
        setTimeout(() => {
          animateTo({ duration: 460, curve: Curve.Friction }, () => {
            this.vesselScale = 1;
            this.glowOpacity = 0.22;
          });
        }, 150);
      }

      if (this.celebrationToken !== this.lastCelebrationToken) {
        this.lastCelebrationToken = this.celebrationToken;
        this.splashEnergy = 1.7;
        animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
          this.vesselScale = 1.055;
          this.glowOpacity = 0.48;
        });
        setTimeout(() => {
          animateTo({ duration: 620, curve: Curve.Friction }, () => {
            this.vesselScale = 1;
            this.glowOpacity = 0.25;
          });
        }, 280);
      }

      this.drawCup();
    }, 32);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) clearInterval(this.timer);
  }

  private waveY(x: number, baseY: number, amplitude: number, phase: number): number {
    return baseY + Math.sin((x / 25) + this.waveOffset + phase) * amplitude +
      Math.sin((x / 48) - this.waveOffset * 0.72 + phase) * amplitude * 0.42;
  }

  private drawWave(baseY: number, bottom: number, color: string, amplitude: number, phase: number): void {
    const ctx: CanvasRenderingContext2D = this.context;
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(32, baseY);
    for (let x: number = 32; x <= 288; x += 5) {
      ctx.lineTo(x, this.waveY(x, baseY, amplitude, phase));
    }
    ctx.lineTo(288, bottom + 8);
    ctx.lineTo(32, bottom + 8);
    ctx.closePath();
    ctx.fill();
  }

  private drawBubble(x: number, waterTop: number, bottom: number, radius: number, speed: number,
    offset: number): void {
    const availableHeight: number = Math.max(18, bottom - waterTop - 14);
    const travel: number = (this.waveOffset * speed + offset) % availableHeight;
    const y: number = bottom - 10 - travel;
    if (y <= waterTop + 7) return;
    const ctx: CanvasRenderingContext2D = this.context;
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fillStyle = '#55FFFFFF';
    ctx.fill();
    ctx.lineWidth = 1;
    ctx.strokeStyle = '#B8FFFFFF';
    ctx.stroke();
  }

  private drawCup(): void {
    const ctx: CanvasRenderingContext2D = this.context;
    const center: number = 160;
    const radius: number = 126;
    const innerRadius: number = 118;
    const top: number = center - innerRadius;
    const bottom: number = center + innerRadius;
    const normalizedProgress: number = Math.max(0, Math.min(this.displayProgress, 1));
    const waterHeight: number = (innerRadius * 2 - 10) * normalizedProgress;
    const waterY: number = bottom - 5 - waterHeight;
    const waveAmplitude: number = 4.5 + this.splashEnergy * 5.5;

    ctx.clearRect(0, 0, 320, 320);
    ctx.save();
    ctx.beginPath();
    ctx.arc(center, center, innerRadius, 0, Math.PI * 2);
    ctx.clip();

    const chamberGradient: CanvasGradient = ctx.createLinearGradient(48, 38, 272, 282);
    chamberGradient.addColorStop(0, '#E8FFFFFF');
    chamberGradient.addColorStop(0.48, '#65F4FCFF');
    chamberGradient.addColorStop(1, '#9EE9F7FF');
    ctx.fillStyle = chamberGradient;
    ctx.fillRect(34, 34, 252, 252);

    if (waterHeight > 1) {
      this.drawWave(waterY + 5, bottom, '#6A74D9F5', waveAmplitude * 0.78, 1.35);

      const waterGradient: CanvasGradient = ctx.createLinearGradient(0, waterY, 0, bottom);
      waterGradient.addColorStop(0, '#D13CC9F2');
      waterGradient.addColorStop(0.34, '#DA26B9E9');
      waterGradient.addColorStop(1, '#EE0A8CCE');
      ctx.fillStyle = waterGradient;
      ctx.beginPath();
      ctx.moveTo(32, waterY);
      for (let x: number = 32; x <= 288; x += 5) {
        ctx.lineTo(x, this.waveY(x, waterY, waveAmplitude, 0));
      }
      ctx.lineTo(288, bottom + 8);
      ctx.lineTo(32, bottom + 8);
      ctx.closePath();
      ctx.fill();

      ctx.beginPath();
      ctx.moveTo(38, waterY - 1);
      for (let x: number = 38; x <= 282; x += 5) {
        ctx.lineTo(x, this.waveY(x, waterY - 1, waveAmplitude, 0));
      }
      ctx.lineWidth = 2.4;
      ctx.strokeStyle = '#D8FFFFFF';
      ctx.stroke();

      this.drawBubble(92, waterY, bottom, 4.1, 6.4, 19);
      this.drawBubble(121, waterY, bottom, 2.4, 8.1, 53);
      this.drawBubble(214, waterY, bottom, 3.2, 7.2, 87);
      this.drawBubble(239, waterY, bottom, 2.2, 9.4, 31);
    }
    ctx.restore();

    const rimGradient: CanvasGradient = ctx.createLinearGradient(56, 48, 266, 278);
    rimGradient.addColorStop(0, '#FFFFFFFF');
    rimGradient.addColorStop(0.42, '#8FD9F2FF');
    rimGradient.addColorStop(0.72, '#FFF4FCFF');
    rimGradient.addColorStop(1, '#8B7FD7F2');
    ctx.beginPath();
    ctx.arc(center, center, radius, 0, Math.PI * 2);
    ctx.lineWidth = 4;
    ctx.strokeStyle = rimGradient;
    ctx.stroke();

    ctx.beginPath();
    ctx.arc(center, center, radius - 7, 0, Math.PI * 2);
    ctx.lineWidth = 1.4;
    ctx.strokeStyle = '#D8FFFFFF';
    ctx.stroke();

    ctx.beginPath();
    ctx.arc(132, 127, 80, Math.PI * 1.08, Math.PI * 1.58);
    ctx.lineWidth = 7;
    ctx.strokeStyle = '#72FFFFFF';
    ctx.stroke();

    if (this.splashEnergy > 0.08) {
      ctx.beginPath();
      ctx.arc(center, center, radius + 8 + this.splashEnergy * 7, 0, Math.PI * 2);
      ctx.lineWidth = 2;
      ctx.strokeStyle = '#56A6E8FF';
      ctx.stroke();
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width(286)
        .height(286)
        .fill('#55A8E8F7')
        .opacity(this.glowOpacity)
        .blur(34)
      Canvas(this.context)
        .width(320)
        .height(320)
        .onReady(() => {
          this.displayProgress = this.progress;
          this.drawCup();
        })
    }
    .width(330)
    .height(330)
    .scale({ x: this.vesselScale, y: this.vesselScale })
  }
}
