// 详情：教材/跑腿/求助 详情 + 费用明细 + 私聊/接单（需认证）+ 举报
import { AppStore, store } from '../common/AppStore';
import { Theme } from '../common/Theme';
import { ErrandType, FeeRow, GoodsItem, GoodsKind, condLabel } from '../model/Models';
import { Avatar, TagBadge, EmptyTip, PageHeader } from '../views/Widgets';

@ComponentV2
export struct DetailPage {
  private fallback: GoodsItem = new GoodsItem();

  private item(): GoodsItem {
    const g = store.findGoods(store.pendingDetailId);
    return g === undefined ? this.fallback : g;
  }

  private exists(): boolean {
    return store.findGoods(store.pendingDetailId) !== undefined;
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
  }

  private contact(item: GoodsItem, firstText: string): void {
    if (!store.me.verified) {
      this.toast('完成学生认证后才能私聊');
      store.go('certify');
      return;
    }
    store.openChatWith(item.sellerId, item.id, firstText).then((err: string): void => {
      if (err.length > 0) {
        this.toast(err);
      }
    });
  }

  private report(item: GoodsItem): void {
    this.getUIContext().showAlertDialog({
      title: '举报该内容',
      message: '若核实违规，对方信用分将被扣除。确定要举报吗？',
      primaryButton: {
        value: '取消',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '举报',
        fontColor: Theme.danger,
        action: (): void => {
          store.reportPeer(item.sellerId, '涉嫌违规内容').then((err: string): void => {
            this.toast(err.length > 0 ? err : '已收到举报，平台将在24小时内核实处理');
          });
        }
      }
    });
  }

  @Builder
  FeeTable(item: GoodsItem) {
    Column({ space: 6 }) {
      Row() {
        Text('费用明细').fontSize(13).fontWeight(FontWeight.Bold).fontColor(Theme.text)
        Blank()
        Text(`合计 ¥${item.price.toFixed(2)}`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.primary)
      }
      .width('100%')

      ForEach(AppStore.errandFeeRows(item.errand), (r: FeeRow) => {
        Row() {
          Text(r.label).fontSize(12).fontColor(Theme.sub)
          Blank()
          Text(`¥${r.amount.toFixed(2)}`).fontSize(12).fontColor(Theme.text)
        }
        .width('100%')
      }, (r: FeeRow) => r.label)
    }
    .padding(12)
    .backgroundColor(Theme.primarySoft)
    .borderRadius(10)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  MetaLine(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(Theme.sub).width(76)
      Text(value).fontSize(12).fontColor(Theme.text).layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({
          title: '详情',
          onBack: (): void => {
            store.nav.pop();
          }
        })

        if (!this.exists()) {
          Column() {
            EmptyTip({ text: '内容不存在或已下架' })
          }
          .layoutWeight(1)
          .width('100%')
        } else {
          Scroll() {
            Column({ space: 12 }) {
              // 安全提示
              Text('安全提示：当面验货 · 不要脱离平台转账 · 任何人索要验证码都是诈骗')
                .fontSize(11)
                .fontColor(Theme.warn)
                .backgroundColor(Theme.warnSoft)
                .padding(10)
                .borderRadius(10)
                .width('100%')

              Column({ space: 8 }) {
                Text(this.item().title)
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Theme.text)
                  .width('100%')
                Text(this.item().desc)
                  .fontSize(13)
                  .fontColor(Theme.sub)
                  .width('100%')
                Text(`发布于 ${this.item().timeText}`)
                  .fontSize(11)
                  .fontColor(Theme.sub)
                  .width('100%')
              }
              .padding(14)
              .backgroundColor(Theme.card)
              .borderRadius(12)
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              // 跑腿参数 / 教材参数
              if (this.item().kind === GoodsKind.Errand) {
                Column({ space: 4 }) {
                  this.MetaLine('类型', this.item().errand.type === ErrandType.Express ? '快递代拿'
                    : (this.item().errand.type === ErrandType.Takeout ? '外卖跑腿' : '食堂代选'))
                  this.MetaLine('份数', `${this.item().errand.pieces} 份`)
                  if (this.item().errand.type === ErrandType.Express) {
                    this.MetaLine('大小', `${this.item().errand.size}`)
                    this.MetaLine('重量', `${this.item().errand.weightKg} kg`)
                  }
                  if (this.item().errand.dishes.length > 0) {
                    this.MetaLine('菜品', this.item().errand.dishes.join('、'))
                  }
                  if (this.item().errand.taste.length > 0) {
                    this.MetaLine('口味', this.item().errand.taste)
                  }
                  this.MetaLine('路线', `${this.item().errand.fromPoint} → ${this.item().errand.toPoint}`)
                }
                .padding(14)
                .backgroundColor(Theme.card)
                .borderRadius(12)
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                this.FeeTable(this.item())
              } else if (this.item().kind === GoodsKind.Textbook) {
                Column({ space: 4 }) {
                  this.MetaLine('课程', this.item().course)
                  this.MetaLine('成色', condLabel(this.item().condition))
                  this.MetaLine('类型', this.item().wanted ? '求购' : '出售')
                }
                .padding(14)
                .backgroundColor(Theme.card)
                .borderRadius(12)
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              // 卖家卡片
              Row({ space: 10 }) {
                Avatar({
                  name: store.findUser(this.item().sellerId).nickname,
                  hue: store.findUser(this.item().sellerId).hue,
                  dim: 44
                })
                Column({ space: 4 }) {
                  Row({ space: 6 }) {
                    Text(store.findUser(this.item().sellerId).nickname)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Theme.text)
                    if (store.findUser(this.item().sellerId).verified) {
                      TagBadge({ label: '杉达认证' })
                    }
                  }
                  Text(`${store.findUser(this.item().sellerId).college} · 信用分 ${store.findUser(this.item().sellerId).credit} · ${store.creditLevel(store.findUser(this.item().sellerId).credit)}`)
                    .fontSize(11)
                    .fontColor(Theme.sub)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(14)
              .backgroundColor(Theme.card)
              .borderRadius(12)
              .alignItems(VerticalAlign.Center)
            }
            .padding({ left: 16, right: 16, bottom: 12 })
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.Top)

          // 底部操作栏
          Row({ space: 10 }) {
            Column({ space: 2 }) {
              Text(this.priceText(this.item()))
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.primary)
              Text('举报')
                .fontSize(10)
                .fontColor(Theme.sub)
                .onClick(() => {
                  this.report(this.item());
                })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('收藏')
              .fontSize(13)
              .fontColor(Theme.primary)
              .border({ width: 1, color: Theme.primary })
              .borderRadius(20)
              .padding({ left: 18, right: 18, top: 9, bottom: 9 })
              .onClick(() => {
                this.toast('已加入收藏（演示）');
              })

            Text(this.actionLabel(this.item()))
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor(Theme.primary)
              .borderRadius(20)
              .padding({ left: 22, right: 22, top: 10, bottom: 10 })
              .onClick(() => {
                this.contact(this.item(), this.firstText(this.item()));
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 14 })
          .backgroundColor(Theme.card)
          .alignItems(VerticalAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg)
    }
    .hideTitleBar(true)
  }

  private priceText(item: GoodsItem): string {
    if (item.kind === GoodsKind.Errand) {
      return `¥${item.price.toFixed(2)}`;
    }
    if (item.kind === GoodsKind.Help) {
      return item.reward > 0 ? `悬赏 ¥${item.reward.toFixed(0)}` : '免费互助';
    }
    return `¥${item.price.toFixed(2)}`;
  }

  private actionLabel(item: GoodsItem): string {
    if (item.kind === GoodsKind.Errand) {
      return '我要接单';
    }
    if (item.kind === GoodsKind.Help) {
      return '帮助TA';
    }
    return '私聊卖家';
  }

  private firstText(item: GoodsItem): string {
    if (item.kind === GoodsKind.Errand) {
      return '你好，我接下了这个跑腿单，请确认交接时间与细节。';
    }
    if (item.kind === GoodsKind.Help) {
      return `你好，我可以帮你处理「${item.title}」。`;
    }
    return `你好，我对「${item.title}」感兴趣，可以面交吗？`;
  }
}
