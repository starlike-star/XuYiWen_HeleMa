import { router } from '@kit.ArkUI';
import { SplashAnimation } from '../components/animations/SplashAnimation';

@Entry
@Component
struct Index {
  private hasNavigated: boolean = false;
  private fallbackTimer: number = -1;

  aboutToAppear(): void {
    this.fallbackTimer = setTimeout(() => this.finishOnce(), 3000);
  }

  aboutToDisappear(): void {
    if (this.fallbackTimer >= 0) clearTimeout(this.fallbackTimer);
  }

  private finishOnce(): void {
    if (this.hasNavigated) return;
    this.hasNavigated = true;
    if (this.fallbackTimer >= 0) clearTimeout(this.fallbackTimer);
    try {
      router.replaceUrl({ url: 'pages/Main' });
    } catch (_) {
      // 一次性守卫仍保持锁定，避免动画回调和兜底同时重复发起路由。
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_background'))
        .expandSafeArea(
          [SafeAreaType.SYSTEM, SafeAreaType.CUTOUT],
          [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]
        )
      SplashAnimation({ onFinished: () => this.finishOnce() })
    }
    .width('100%')
    .height('100%')
  }
}
