// 集市：分类浏览 + 搜索 + 认证横幅 + 安全提示
import { store } from '../common/AppStore';
import { Theme } from '../common/Theme';
import { GoodsItem, GoodsKind } from '../model/Models';
import { GoodsCard } from '../views/GoodsCard';
import { EmptyTip } from '../views/Widgets';

@ComponentV2
export struct HomePage {
  @Local kindIdx: number = 0;
  @Local searchText: string = '';
  readonly kinds: string[] = ['全部', '二手教材', '校园跑腿', '求助专区'];

  private filtered(): GoodsItem[] {
    let list: GoodsItem[] = store.goods;
    if (this.kindIdx === 1) {
      list = list.filter((g: GoodsItem): boolean => g.kind === GoodsKind.Textbook);
    } else if (this.kindIdx === 2) {
      list = list.filter((g: GoodsItem): boolean => g.kind === GoodsKind.Errand);
    } else if (this.kindIdx === 3) {
      list = list.filter((g: GoodsItem): boolean => g.kind === GoodsKind.Help);
    }
    const kw = this.searchText.trim();
    if (kw.length > 0) {
      list = list.filter((g: GoodsItem): boolean =>
        g.title.includes(kw) || g.desc.includes(kw) || g.course.includes(kw));
    }
    return list;
  }

  aboutToAppear(): void {
    store.refreshGoods();
  }

  build() {
    Column() {
      Column({ space: 8 }) {
        Row() {
          Text('杉达集市')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.text)
          Blank()
          Text('安全集市 · 拒绝私下交易')
            .fontSize(11)
            .fontColor(Theme.primary)
            .backgroundColor(Theme.primarySoft)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(10)
        }
        .width('100%')

        if (store.offline) {
          Row({ space: 8 }) {
            Text('无法连接集市服务，请确认后端已启动')
              .fontSize(12)
              .fontColor(Theme.danger)
              .layoutWeight(1)
            Text('重试')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.primary)
              .onClick(() => {
                store.retryInit();
              })
          }
          .width('100%')
          .padding(10)
          .backgroundColor(Theme.dangerSoft)
          .borderRadius(10)
        }

        if (!store.me.verified) {
          Row({ space: 8 }) {
            Text('未完成杉达学生认证：发布、接单、私聊受限')
              .fontSize(12)
              .fontColor(Theme.warn)
              .layoutWeight(1)
            Text('去认证 ›')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.warn)
              .onClick(() => {
                store.go('certify');
              })
          }
          .width('100%')
          .padding(10)
          .backgroundColor(Theme.warnSoft)
          .borderRadius(10)
        } else {
          Row({ space: 8 }) {
            Text(`已认证 · ${store.me.college} · 学号 ${store.me.studentNoMasked}`)
              .fontSize(12)
              .fontColor(Theme.primary)
              .layoutWeight(1)
              .maxLines(1)
            Text(`信用分 ${store.me.credit}`)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.primary)
          }
          .width('100%')
          .padding(10)
          .backgroundColor(Theme.primarySoft)
          .borderRadius(10)
        }

        TextInput({ placeholder: '搜索教材、跑腿、求助…' })
          .height(38)
          .fontSize(13)
          .backgroundColor(Theme.card)
          .borderRadius(10)
          .onChange((v: string) => {
            this.searchText = v;
          })
      }
      .padding({ left: 16, right: 16, top: 12, bottom: 4 })
      .width('100%')

      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.kinds, (k: string, idx: number) => {
            Text(k)
              .fontSize(13)
              .fontColor(this.kindIdx === idx ? Color.White : Theme.sub)
              .backgroundColor(this.kindIdx === idx ? Theme.primary : Theme.card)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(16)
              .onClick(() => {
                this.kindIdx = idx;
              })
          }, (k: string) => k)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 4 })

      if (this.filtered().length === 0) {
        Column() {
          EmptyTip({ text: '没有找到相关内容' })
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        List({ space: 10 }) {
          ForEach(this.filtered(), (g: GoodsItem) => {
            ListItem() {
              GoodsCard({
                item: g,
                onOpen: (): void => {
                  store.openDetail(g.id);
                }
              })
            }
          }, (g: GoodsItem) => g.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
  }
}
