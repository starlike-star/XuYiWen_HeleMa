import { GlassNavigation } from '../components/common/GlassNavigation';
import { StatusPanel } from '../components/common/StatusPanel';
import { WaterStore } from '../store/WaterStore';
import { HistoryView } from './views/HistoryView';
import { HomeView } from './views/HomeView';

@Entry
@Component
struct Main {
  @State private selectedIndex: number = 0;
  @State private store: WaterStore = new WaterStore();

  aboutToAppear(): void {
    this.store.load();
  }

  private selectTab(index: number): void {
    animateTo({ duration: 420, curve: Curve.Friction }, () => {
      this.selectedIndex = index;
    });
    if (index === 1) this.store.refreshHistory();
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#F4FAFC')
        .expandSafeArea(
          [SafeAreaType.SYSTEM, SafeAreaType.CUTOUT],
          [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]
        )

      if (this.store.isLoading || this.store.errorMessage.length > 0) {
        Column() {
          StatusPanel({
            loading: this.store.isLoading,
            message: this.store.errorMessage,
            onRetry: () => this.store.load()
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        if (this.selectedIndex === 0) {
          HomeView({
            store: this.store,
            onOpenHistory: () => this.selectTab(1)
          })
        } else {
          HistoryView({ store: this.store })
        }

        GlassNavigation({
          selectedIndex: this.selectedIndex,
          onSelect: (index: number) => this.selectTab(index)
        })
        .margin({ bottom: 22 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
