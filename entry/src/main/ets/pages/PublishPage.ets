// 发布：二手教材 / 快递代拿(大小·重量·份数) / 外卖跑腿(份数) / 食堂代选(菜单+口味) / 求助
// 未认证用户无法发布（信任门槛）
import { AppStore, store } from '../common/AppStore';
import { SensitiveFilter } from '../common/SensitiveFilter';
import { Theme } from '../common/Theme';
import {
  BookCondition, ErrandInfo, ErrandType, FeeRow, GoodsItem, GoodsKind
} from '../model/Models';
import { Chip, EmptyTip } from '../views/Widgets';

interface PubOption {
  label: string;
  kind: GoodsKind;
  et: ErrandType;
}

@ComponentV2
export struct PublishPage {
  @Local pubIdx: number = 0;
  readonly options: PubOption[] = [
    { label: '二手教材', kind: GoodsKind.Textbook, et: ErrandType.Express },
    { label: '快递代拿', kind: GoodsKind.Errand, et: ErrandType.Express },
    { label: '外卖跑腿', kind: GoodsKind.Errand, et: ErrandType.Takeout },
    { label: '食堂代选', kind: GoodsKind.Errand, et: ErrandType.Canteen },
    { label: '求助', kind: GoodsKind.Help, et: ErrandType.Express }
  ];

  // 教材
  @Local title: string = '';
  @Local course: string = '';
  @Local desc: string = '';
  @Local priceText: string = '';
  @Local condIdx: number = 1;
  @Local wanted: boolean = false;
  readonly conds: string[] = ['全新', '九成新', '八成新', '明显使用'];

  // 跑腿通用
  @Local fromPoint: string = '';
  @Local toPoint: string = '';
  @Local pieces: number = 1;
  @Local pkgSize: string = 'M';
  @Local weightText: string = '';
  readonly sizes: string[] = ['S', 'M', 'L', 'XL'];
  readonly sizeDesc: Record<string, string> = { 'S': '≈鞋盒', 'M': '≈手提袋', 'L': '≈中纸箱', 'XL': '≈大件' };

  // 食堂代选
  @Local canteen: string = '二食堂';
  @Local window: string = '';
  @Local dishes: string[] = [];
  @Local tastes: string[] = [];
  @Local tasteNote: string = '';
  readonly canteens: string[] = ['一食堂', '二食堂', '三餐'];
  readonly menus: Record<string, string[]> = {
    '一食堂': ['卤肉饭', '蛋炒饭', '石锅拌饭', '大盘鸡拌面'],
    '二食堂': ['麻辣香锅', '黄焖鸡米饭', '麻辣烫', '铁板鱿鱼饭'],
    '三餐': ['汉堡套餐', '炒河粉', '水饺']
  };
  readonly tasteOptions: string[] = ['微辣', '中辣', '免辣', '不要香菜', '少油', '多醋'];

  // 求助
  @Local rewardText: string = '';

  private kind(): GoodsKind {
    return this.options[this.pubIdx].kind;
  }

  private et(): ErrandType {
    return this.options[this.pubIdx].et;
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
  }

  private condOf(i: number): BookCondition {
    if (i === 0) {
      return BookCondition.New;
    }
    if (i === 1) {
      return BookCondition.LikeNew;
    }
    if (i === 2) {
      return BookCondition.Good;
    }
    return BookCondition.Worn;
  }

  private buildErrand(): ErrandInfo {
    const e = new ErrandInfo();
    e.type = this.et();
    e.pieces = this.pieces;
    e.size = this.pkgSize;
    e.weightKg = parseFloat(this.weightText) || 0;
    if (e.type === ErrandType.Canteen) {
      e.fromPoint = this.canteen + (this.window.trim().length > 0 ? `·${this.window.trim()}` : '');
      e.dishes = this.dishes;
      let taste = this.tastes.join('·');
      if (this.tasteNote.trim().length > 0) {
        taste = taste.length > 0 ? `${taste}·${this.tasteNote.trim()}` : this.tasteNote.trim();
      }
      e.taste = taste;
    } else {
      e.fromPoint = this.fromPoint.trim();
    }
    e.toPoint = this.toPoint.trim();
    return e;
  }

  private rows(): FeeRow[] {
    return AppStore.errandFeeRows(this.buildErrand());
  }

  private toggleIn(arr: string[], v: string): string[] {
    if (arr.includes(v)) {
      return arr.filter((x: string): boolean => x !== v);
    }
    const next = arr.slice();
    next.push(v);
    return next;
  }

  private publish(): void {
    const g = new GoodsItem();
    g.kind = this.kind();
    g.title = this.title.trim();
    g.desc = this.desc.trim();

    if (this.kind() === GoodsKind.Textbook) {
      if (g.title.length === 0 || this.course.trim().length === 0) {
        this.toast('请填写书名与课程');
        return;
      }
      const price = parseFloat(this.priceText);
      if (isNaN(price) || price <= 0) {
        this.toast('请填写正确的价格');
        return;
      }
      g.course = this.course.trim();
      g.condition = this.condOf(this.condIdx);
      g.price = price;
      g.wanted = this.wanted;
    } else if (this.kind() === GoodsKind.Errand) {
      const e = this.buildErrand();
      if (e.fromPoint.length === 0 || e.toPoint.length === 0) {
        this.toast('请填写取货点与送达点');
        return;
      }
      if (e.type === ErrandType.Canteen && e.dishes.length === 0) {
        this.toast('请至少选择一个菜品');
        return;
      }
      if (e.type === ErrandType.Express && e.weightKg < 0) {
        this.toast('请填写正确的重量');
        return;
      }
      g.errand = e;
      g.price = AppStore.feeTotal(this.rows());
    } else {
      if (g.title.length === 0 || g.desc.length === 0) {
        this.toast('请填写标题与内容');
        return;
      }
      g.reward = parseFloat(this.rewardText) || 0;
    }

    const tipWord = SensitiveFilter.hasSensitive(`${g.title}${g.desc}`)
      ? '（发布内容中的个人信息已自动隐藏）'
      : '';
    store.publish(g).then((err: string): void => {
      if (err.length > 0) {
        this.toast(err);
        return;
      }
      this.title = '';
      this.course = '';
      this.desc = '';
      this.priceText = '';
      this.rewardText = '';
      this.dishes = [];
      this.tastes = [];
      this.pieces = 1;
      this.weightText = '';
      this.toast(`发布成功${tipWord}`);
      store.switchTab(0);
    });
  }

  @Builder
  Label(text: string) {
    Text(text).fontSize(13).fontColor(Theme.sub).margin({ top: 10, bottom: 4 })
  }

  @Builder
  Input(placeholder: string, text: string, onChange: (v: string) => void) {
    TextInput({ placeholder: placeholder, text: text })
      .height(40)
      .fontSize(13)
      .backgroundColor(Theme.bg)
      .borderRadius(8)
      .onChange(onChange)
  }

  @Builder
  FeeCard() {
    Column({ space: 6 }) {
      Row() {
        Text('跑腿费明细（公平计价）')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.text)
        Blank()
        Text(`合计 ¥${AppStore.feeTotal(this.rows()).toFixed(2)}`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.primary)
      }
      .width('100%')

      ForEach(this.rows(), (r: FeeRow) => {
        Row() {
          Text(r.label).fontSize(12).fontColor(Theme.sub)
          Blank()
          Text(`¥${r.amount.toFixed(2)}`).fontSize(12).fontColor(Theme.text)
        }
        .width('100%')
      }, (r: FeeRow) => r.label)

      Text('按份数 / 快递大小 / 重量统一计价，保证接单与发单公平。')
        .fontSize(10)
        .fontColor(Theme.sub)
        .width('100%')
    }
    .padding(12)
    .backgroundColor(Theme.primarySoft)
    .borderRadius(10)
    .width('100%')
    .margin({ top: 12 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  PiecesStepper() {
    Row({ space: 12 }) {
      Text('份数').fontSize(13).fontColor(Theme.sub)
      Blank()
      Text('－')
        .fontSize(16)
        .fontColor(this.pieces > 1 ? Theme.primary : Theme.line)
        .width(32)
        .height(32)
        .textAlign(TextAlign.Center)
        .backgroundColor(Theme.bg)
        .borderRadius(8)
        .onClick(() => {
          if (this.pieces > 1) {
            this.pieces--;
          }
        })
      Text(`${this.pieces}`)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.text)
        .width(36)
        .textAlign(TextAlign.Center)
      Text('＋')
        .fontSize(16)
        .fontColor(Theme.primary)
        .width(32)
        .height(32)
        .textAlign(TextAlign.Center)
        .backgroundColor(Theme.primarySoft)
        .borderRadius(8)
        .onClick(() => {
          if (this.pieces < 20) {
            this.pieces++;
          }
        })
    }
    .width('100%')
    .margin({ top: 10 })
  }

  build() {
    if (!store.me.verified) {
      Column({ space: 14 }) {
        EmptyTip({ text: '完成杉达学生认证后即可发布' })
        Text('去认证')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(Theme.primary)
          .borderRadius(20)
          .padding({ left: 32, right: 32, top: 10, bottom: 10 })
          .onClick(() => {
            store.go('certify');
          })
        Text('认证仅限本校学生发布内容，是集市信任体系的第一道门槛。')
          .fontSize(11)
          .fontColor(Theme.sub)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg)
      .justifyContent(FlexAlign.Center)
    } else {
      Column() {
        Scroll() {
          Column() {
            Text('发布')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.text)
              .width('100%')
              .margin({ bottom: 4 })

            Text('所有发布内容会自动隐藏个人信息')
              .fontSize(11)
              .fontColor(Theme.sub)
              .width('100%')

            // 类型选择
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(this.options, (o: PubOption, idx: number) => {
                Chip({
                  label: o.label,
                  selected: this.pubIdx === idx,
                  onSelect: (): void => {
                    this.pubIdx = idx;
                  }
                }).margin({ right: 8, top: 8 })
              }, (o: PubOption) => o.label)
            }
            .width('100%')

            this.Label('标题')
            this.Input(this.kind() === GoodsKind.Textbook ? '如：高等数学(上) 同济第七版' : '一句话说明需求', this.title, (v: string): void => {
              this.title = v;
            })

            if (this.kind() === GoodsKind.Textbook) {
              this.Label('课程名称')
              this.Input('如：高等数学', this.course, (v: string): void => {
                this.course = v;
              })

              this.Label('成色')
              Row({ space: 8 }) {
                ForEach(this.conds, (c: string, idx: number) => {
                  Chip({
                    label: c,
                    selected: this.condIdx === idx,
                    onSelect: (): void => {
                      this.condIdx = idx;
                    }
                  })
                }, (c: string) => c)
              }
              .width('100%')

              this.Label(this.wanted ? '期望价格(¥)' : '价格(¥)')
              this.Input('0.00', this.priceText, (v: string): void => {
                this.priceText = v;
              })

              Row({ space: 8 }) {
                Text('我是求购').fontSize(13).fontColor(Theme.sub)
                Toggle({ type: ToggleType.Switch, isOn: this.wanted })
                  .selectedColor(Theme.primary)
                  .onChange((on: boolean): void => {
                    this.wanted = on;
                  })
              }
              .width('100%')
              .margin({ top: 10 })
            } else if (this.kind() === GoodsKind.Errand) {
              if (this.et() === ErrandType.Canteen) {
                this.Label('选择食堂')
                Row({ space: 8 }) {
                  ForEach(this.canteens, (c: string) => {
                    Chip({
                      label: c,
                      selected: this.canteen === c,
                      onSelect: (): void => {
                        this.canteen = c;
                        this.dishes = [];
                      }
                    })
                  }, (c: string) => c)
                }
                .width('100%')

                this.Label('窗口(可选)')
                this.Input('如：麻辣香锅窗口', this.window, (v: string): void => {
                  this.window = v;
                })

                this.Label('菜单选菜(可多选)')
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.menus[this.canteen], (d: string) => {
                    Chip({
                      label: d,
                      selected: this.dishes.includes(d),
                      onSelect: (): void => {
                        this.dishes = this.toggleIn(this.dishes, d);
                      }
                    }).margin({ right: 8, top: 8 })
                  }, (d: string) => d)
                }
                .width('100%')

                this.Label('口味选择(可多选)')
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.tasteOptions, (t: string) => {
                    Chip({
                      label: t,
                      selected: this.tastes.includes(t),
                      onSelect: (): void => {
                        this.tastes = this.toggleIn(this.tastes, t);
                      }
                    }).margin({ right: 8, top: 8 })
                  }, (t: string) => t)
                }
                .width('100%')

                this.Label('忌口备注(可选)')
                this.Input('如：对花生过敏', this.tasteNote, (v: string): void => {
                  this.tasteNote = v;
                })
              } else {
                this.Label(this.et() === ErrandType.Express ? '取货点(如：菜鸟驿站)' : '取餐点(如：北门外卖架)')
                this.Input('填写具体位置', this.fromPoint, (v: string): void => {
                  this.fromPoint = v;
                })
              }

              if (this.et() === ErrandType.Express) {
                this.Label('快递大小')
                Row({ space: 8 }) {
                  ForEach(this.sizes, (s: string) => {
                    Chip({
                      label: `${s} ${this.sizeDesc[s]}`,
                      selected: this.pkgSize === s,
                      onSelect: (): void => {
                        this.pkgSize = s;
                      }
                    })
                  }, (s: string) => s)
                }
                .width('100%')

                this.Label('重量(kg)')
                this.Input('如：3.5', this.weightText, (v: string): void => {
                  this.weightText = v;
                })
              }

              this.PiecesStepper()

              this.Label('送达点(宿舍楼/教学楼)')
              this.Input('如：西区6号楼', this.toPoint, (v: string): void => {
                this.toPoint = v;
              })

              this.FeeCard()
            } else {
              this.Label('详细说明')
              TextArea({ placeholder: '描述你的求助内容…', text: this.desc })
                .height(90)
                .fontSize(13)
                .backgroundColor(Theme.bg)
                .borderRadius(8)
                .onChange((v: string): void => {
                  this.desc = v;
                })

              this.Label('感谢金(¥，可不填)')
              this.Input('0', this.rewardText, (v: string): void => {
                this.rewardText = v;
              })
            }

            if (this.kind() === GoodsKind.Textbook) {
              this.Label('描述(可选)')
              TextArea({ placeholder: '笔记情况、是否有配套资料…', text: this.desc })
                .height(80)
                .fontSize(13)
                .backgroundColor(Theme.bg)
                .borderRadius(8)
                .onChange((v: string): void => {
                  this.desc = v;
                })
            }

            Text('发布')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor(Theme.primary)
              .borderRadius(22)
              .width('100%')
              .height(44)
              .textAlign(TextAlign.Center)
              .margin({ top: 20, bottom: 30 })
              .onClick(() => {
                this.publish();
              })
          }
          .padding(16)
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg)
    }
  }
}
