// 商品/跑腿/求助 卡片
import { store } from '../common/AppStore';
import { Theme } from '../common/Theme';
import { ErrandType, GoodsItem, GoodsKind, condLabel } from '../model/Models';
import { Avatar, TagBadge } from './Widgets';

@ComponentV2
export struct GoodsCard {
  @Param item: GoodsItem = new GoodsItem();
  @Param onOpen: () => void = (): void => {};

  private kindLabel(): string {
    if (this.item.kind === GoodsKind.Textbook) {
      return this.item.wanted ? '求购教材' : '二手教材';
    }
    if (this.item.kind === GoodsKind.Errand) {
      if (this.item.errand.type === ErrandType.Express) {
        return '快递代拿';
      }
      if (this.item.errand.type === ErrandType.Takeout) {
        return '外卖跑腿';
      }
      return '食堂代选';
    }
    return this.item.reward > 0 ? '悬赏求助' : '求助/失物';
  }

  private kindFg(): string {
    if (this.item.kind === GoodsKind.Textbook) {
      return Theme.blue;
    }
    if (this.item.kind === GoodsKind.Errand) {
      return Theme.primary;
    }
    return Theme.warn;
  }

  private kindBg(): string {
    if (this.item.kind === GoodsKind.Textbook) {
      return Theme.blueSoft;
    }
    if (this.item.kind === GoodsKind.Errand) {
      return Theme.primarySoft;
    }
    return Theme.warnSoft;
  }

  private priceText(): string {
    if (this.item.kind === GoodsKind.Errand) {
      return `跑腿费 ¥${this.item.price.toFixed(2)}`;
    }
    if (this.item.kind === GoodsKind.Help) {
      return this.item.reward > 0 ? `悬赏 ¥${this.item.reward.toFixed(0)}` : '免费互助';
    }
    return `¥${this.item.price.toFixed(2)}`;
  }

  private errandLine(): string {
    const e = this.item.errand;
    let line = `份数 ×${e.pieces}`;
    if (e.type === ErrandType.Express) {
      line += ` · 大小 ${e.size}`;
      if (e.weightKg > 0) {
        line += ` · ${e.weightKg}kg`;
      }
    }
    if (e.taste.length > 0) {
      line += ` · ${e.taste}`;
    }
    if (e.fromPoint.length > 0) {
      line += `\n${e.fromPoint} → ${e.toPoint}`;
    }
    return line;
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Avatar({ name: store.findUser(this.item.sellerId).nickname, hue: store.findUser(this.item.sellerId).hue })
        Column({ space: 3 }) {
          Row({ space: 6 }) {
            Text(store.findUser(this.item.sellerId).nickname)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.text)
            TagBadge({ label: '杉达认证', fg: Theme.primary, bg: Theme.primarySoft })
          }
          Text(`${store.findUser(this.item.sellerId).college} · 信用分 ${store.findUser(this.item.sellerId).credit}`)
            .fontSize(11)
            .fontColor(Theme.sub)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.priceText())
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.item.kind === GoodsKind.Help && this.item.reward === 0 ? Theme.sub : Theme.primary)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        TagBadge({ label: this.kindLabel(), fg: this.kindFg(), bg: this.kindBg() })
        Text(this.item.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')

      Text(this.item.desc)
        .fontSize(12)
        .fontColor(Theme.sub)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (this.item.kind === GoodsKind.Errand) {
        Text(this.errandLine())
          .fontSize(11)
          .fontColor(Theme.blue)
          .backgroundColor(Theme.blueSoft)
          .padding(6)
          .borderRadius(6)
          .width('100%')
      }
      if (this.item.kind === GoodsKind.Textbook) {
        Text(`${this.item.course} · ${condLabel(this.item.condition)}`)
          .fontSize(11)
          .fontColor(Theme.sub)
          .width('100%')
      }

      Row() {
        Text(this.item.timeText).fontSize(11).fontColor(Theme.sub)
        Blank()
        Text('查看详情 ›').fontSize(11).fontColor(Theme.primary)
      }
      .width('100%')
    }
    .padding(12)
    .backgroundColor(Theme.card)
    .borderRadius(12)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.onOpen();
    })
  }
}
