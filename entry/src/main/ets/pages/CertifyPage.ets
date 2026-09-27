// 杉达学生认证：学号校验 + 学院选择（学号脱敏展示，仅用于校验）
import { store } from '../common/AppStore';
import { Theme } from '../common/Theme';
import { Chip, PageHeader } from '../views/Widgets';

@ComponentV2
export struct CertifyPage {
  @Local name: string = '';
  @Local studentNo: string = '';
  @Local college: string = '';
  readonly colleges: string[] = [
    '信息科学与技术学院', '商学院', '教育学院', '艺术设计学院', '护理学院', '国际医学院'
  ];

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
  }

  private submit(): void {
    store.certify(this.name, this.studentNo, this.college).then((err: string): void => {
      if (err.length === 0) {
        this.toast('认证通过，欢迎加入杉达集市');
        store.nav.pop();
      } else {
        this.toast(err);
      }
    });
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({
          title: '杉达学生认证',
          onBack: (): void => {
            store.nav.pop();
          }
        })

        Scroll() {
          Column() {
            if (store.me.verified) {
              Column({ space: 10 }) {
                Text('已完成认证')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Theme.primary)
                Text(`${store.me.nickname} · ${store.me.college}`)
                  .fontSize(13)
                  .fontColor(Theme.text)
                Text(`学号 ${store.me.studentNoMasked}（脱敏展示）`)
                  .fontSize(12)
                  .fontColor(Theme.sub)
                Text('认证信息仅用于平台校验，不会展示给其他同学。')
                  .fontSize(11)
                  .fontColor(Theme.sub)
              }
              .padding(16)
              .backgroundColor(Theme.primarySoft)
              .borderRadius(12)
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            } else {
              Column() {
                Text('真实姓名')
                  .fontSize(13)
                  .fontColor(Theme.sub)
                  .margin({ top: 10, bottom: 4 })
                TextInput({ placeholder: '与校园卡一致', text: this.name })
                  .height(40)
                  .fontSize(13)
                  .backgroundColor(Theme.bg)
                  .borderRadius(8)
                  .onChange((v: string): void => {
                    this.name = v;
                  })

                Text('学号')
                  .fontSize(13)
                  .fontColor(Theme.sub)
                  .margin({ top: 10, bottom: 4 })
                TextInput({ placeholder: '8-12位数字', text: this.studentNo })
                  .height(40)
                  .fontSize(13)
                  .backgroundColor(Theme.bg)
                  .borderRadius(8)
                  .onChange((v: string): void => {
                    this.studentNo = v;
                  })

                Text('所在学院')
                  .fontSize(13)
                  .fontColor(Theme.sub)
                  .margin({ top: 10, bottom: 4 })
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.colleges, (c: string) => {
                    Chip({
                      label: c,
                      selected: this.college === c,
                      onSelect: (): void => {
                        this.college = c;
                      }
                    }).margin({ right: 8, top: 8 })
                  }, (c: string) => c)
                }
                .width('100%')

                Text('提交认证')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .backgroundColor(Theme.primary)
                  .borderRadius(22)
                  .width('100%')
                  .height(44)
                  .textAlign(TextAlign.Center)
                  .margin({ top: 20 })
                  .onClick(() => {
                    this.submit();
                  })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            Column({ space: 6 }) {
              Text('为什么需要认证？')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.text)
              Text('· 交易双方均为杉达在校学生，从源头减少校外诈骗')
                .fontSize(12).fontColor(Theme.sub).width('100%')
              Text('· 认证后才能发布、接单、私聊，浏览不受限')
                .fontSize(12).fontColor(Theme.sub).width('100%')
              Text('· 学号仅用于校验并脱敏展示（如 23****17）')
                .fontSize(12).fontColor(Theme.sub).width('100%')
              Text('· 认证成功信用分 +2')
                .fontSize(12).fontColor(Theme.sub).width('100%')
            }
            .padding(14)
            .backgroundColor(Theme.card)
            .borderRadius(12)
            .width('100%')
            .margin({ top: 14 })
            .alignItems(HorizontalAlign.Start)
          }
          .padding(16)
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg)
    }
    .hideTitleBar(true)
  }
}
