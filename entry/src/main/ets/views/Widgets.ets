// 通用小组件
import { Theme } from '../common/Theme';

@ComponentV2
export struct TagBadge {
  @Param label: string = '';
  @Param fg: string = Theme.primary;
  @Param bg: string = Theme.primarySoft;

  build() {
    Text(this.label)
      .fontSize(10)
      .fontColor(this.fg)
      .backgroundColor(this.bg)
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .borderRadius(4)
      .maxLines(1)
  }
}

@ComponentV2
export struct Avatar {
  @Param name: string = '';
  @Param hue: string = Theme.primary;
  @Param dim: number = 36;

  build() {
    Text(this.name.length > 0 ? this.name.substring(0, 1) : '?')
      .fontSize(this.dim * 0.42)
      .fontColor(Color.White)
      .backgroundColor(this.hue)
      .width(this.dim)
      .height(this.dim)
      .borderRadius(this.dim / 2)
      .textAlign(TextAlign.Center)
  }
}

@ComponentV2
export struct Chip {
  @Param label: string = '';
  @Param selected: boolean = false;
  @Param onSelect: () => void = (): void => {};

  build() {
    Text(this.label)
      .fontSize(13)
      .fontColor(this.selected ? Theme.primary : Theme.sub)
      .backgroundColor(this.selected ? Theme.primarySoft : Theme.card)
      .border({ width: 1, color: this.selected ? Theme.primary : Theme.line })
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .onClick(() => {
        this.onSelect();
      })
  }
}

@ComponentV2
export struct EmptyTip {
  @Param text: string = '暂无内容';

  build() {
    Column({ space: 8 }) {
      Text('—').fontSize(20).fontColor(Theme.line)
      Text(this.text).fontSize(13).fontColor(Theme.sub)
    }
    .width('100%')
    .padding(40)
    .alignItems(HorizontalAlign.Center)
  }
}

@ComponentV2
export struct PageHeader {
  @Param title: string = '';
  @Param onBack: () => void = (): void => {};

  build() {
    Row({ space: 8 }) {
      Text('‹')
        .fontSize(26)
        .fontColor(Theme.text)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .borderRadius(18)
        .backgroundColor(Theme.card)
        .onClick(() => {
          this.onBack();
        })
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.text)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 12, right: 16, top: 8, bottom: 8 })
  }
}
