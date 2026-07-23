let cardStorage: LocalStorage = new LocalStorage();

@Entry(cardStorage)
@Component
struct WaterCard {
  @LocalStorageProp('loggedIn') loggedIn: boolean = false;
  @LocalStorageProp('count') count: number = 0;
  @LocalStorageProp('target') target: number = 0;
  @LocalStorageProp('percent') percent: number = 0;
  @LocalStorageProp('lastDrinkTime') lastDrinkTime: string = '--:--';
  @LocalStorageProp('updatedAt') updatedAt: string = '';
  @LocalStorageProp('possiblyStale') possiblyStale: boolean = false;

  build() {
    Column({ space: 9 }) {
      Row() {
        Text('喝了吗').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        Blank()
        Text(this.loggedIn ? '' : '未登录')
          .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.accent_primary'))
      }.width('100%')

      if (this.loggedIn) {
        Row({ space: 12 }) {
          Stack({ alignContent: Alignment.Center }) {
            Progress({ value: this.percent, total: 100, type: ProgressType.Ring })
              .width(66).height(66).color($r('app.color.accent_primary'))
              .backgroundColor($r('app.color.chart_track')).style({ strokeWidth: 7 })
            Text(`${this.percent}%`)
              .fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_heading'))
          }
          .width(72).height(72)
          .onClick(() => {
            postCardAction(this, {
              action: 'router',
              abilityName: 'EntryAbility',
              params: { source: 'waterCardProgress' }
            });
          })

          Column({ space: 5 }) {
            Text('今日次数 / 目标').fontSize(11).fontColor($r('app.color.text_secondary'))
            Text(`${this.count} / ${this.target} 次`).fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_heading')).maxLines(1)
            Text(`上次 ${this.lastDrinkTime}`).fontSize(11)
              .fontColor($r('app.color.text_secondary')).maxLines(1)
            Text(this.possiblyStale ? `${this.updatedAt} · 可能非最新` : `更新 ${this.updatedAt}`)
              .fontSize(9).fontColor($r('app.color.text_tertiary')).maxLines(1)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)

          Button() {
            Column({ space: 1 }) {
              Image($r('app.media.water_checkin_cup'))
                .width(42).height(42).objectFit(ImageFit.Contain)
              Text('喝水').fontSize(12).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.accent_primary'))
            }
          }
          .width(72).height(72).borderRadius(23)
          .backgroundColor($r('app.color.accent_soft'))
          .onClick(() => {
            postCardAction(this, {
              action: 'message',
              params: { msg: 'checkIn', actionName: 'checkIn' }
            });
          })
        }.width('100%')
      } else {
        Row({ space: 12 }) {
          Stack({ alignContent: Alignment.Center }) {
            Progress({ value: 0, total: 100, type: ProgressType.Ring })
              .width(66).height(66).color($r('app.color.accent_primary'))
              .backgroundColor($r('app.color.chart_track')).style({ strokeWidth: 7 })
            Text('登录').fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_heading'))
          }
          .width(72).height(72)
          .onClick(() => {
            postCardAction(this, {
              action: 'router',
              abilityName: 'EntryAbility',
              params: { source: 'waterCardProgress' }
            });
          })

          Column({ space: 5 }) {
            Text('登录后查看今日喝水进度').fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_heading'))
            Text('点击左侧进度圈打开应用登录').fontSize(12).fontColor($r('app.color.text_secondary'))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)

          Column({ space: 1 }) {
            Image($r('app.media.water_checkin_cup'))
              .width(38).height(38).objectFit(ImageFit.Contain)
            Text('登录后').fontSize(11).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
          }
          .width(72).height(72).justifyContent(FlexAlign.Center)
          .borderRadius(23).backgroundColor($r('app.color.accent_soft')).opacity(0.55)
        }.width('100%')
      }

    }
    .width('100%').height('100%').padding(16)
    .backgroundColor($r('app.color.surface_primary'))
  }
}
