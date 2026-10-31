// 学生认证：手机号实名核验 + 学号校验 + 学院选择（学号/手机号均脱敏存储与展示）
import { store } from '../common/AppStore';
import { Theme } from '../common/Theme';
import { Chip, PageHeader } from '../views/Widgets';

@ComponentV2
export struct CertifyPage {
  @Local name: string = '';
  @Local studentNo: string = '';
  @Local college: string = '';
  @Local phone: string = '';
  @Local smsCode: string = '';
  @Local countdown: number = 0;
  private timerId: number = -1;
  readonly colleges: string[] = [
    '信息科学与技术学院', '商学院', '教育学院', '艺术设计学院', '护理学院', '国际医学院'
  ];

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
  }

  private sendCode(): void {
    if (this.countdown > 0) {
      return;
    }
    store.sendCode(this.phone).then((err: string): void => {
      if (err.startsWith('验证码已发送')) {
        this.toast(err);
        this.countdown = 60;
        this.timerId = setInterval((): void => {
          this.countdown -= 1;
          if (this.countdown <= 0 && this.timerId >= 0) {
            clearInterval(this.timerId);
            this.timerId = -1;
          }
        }, 1000);
      } else if (err.length > 0) {
        this.toast(err);
      }
    });
  }

  private submit(): void {
    // 客户端先行校验：手机号实名核验 + 认证信息
    if (!/^1[3-9]\d{9}$/.test(this.phone.trim())) {
      this.toast('请输入正确的11位手机号');
      return;
    }
    if (this.smsCode.trim().length !== 6) {
      this.toast('请输入6位短信验证码');
      return;
    }
    if (this.name.trim().length < 2 || this.name.trim().length > 20) {
      this.toast('请输入真实姓名（2-20个字符）');
      return;
    }
    if (!/^\d{8,12}$/.test(this.studentNo.trim())) {
      this.toast('学号需为8-12位数字，请核对后重试');
      return;
    }
    if (this.college.length === 0) {
      this.toast('请选择所在学院');
      return;
    }
    store.certify(this.name.trim(), this.studentNo.trim(), this.college, this.phone.trim(), this.smsCode.trim())
      .then((err: string): void => {
        if (err.length === 0) {
          this.toast('认证通过，欢迎加入杉集');
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
          title: '学生认证',
          onBack: (): void => {
            store.nav.pop();
          }
        })

        Scroll() {
          Column() {
            if (store.isRealnamed()) {
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
                if (store.me.phoneMasked.length > 0) {
                  Text(`手机号 ${store.me.phoneMasked}（已实名核验）`)
                    .fontSize(12)
                    .fontColor(Theme.sub)
                }
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
                Text('手机号（用于实名核验）')
                  .fontSize(13)
                  .fontColor(Theme.sub)
                  .margin({ top: 10, bottom: 4 })
                Row() {
                  TextInput({ placeholder: '11位手机号', text: this.phone })
                    .type(InputType.PhoneNumber)
                    .height(40)
                    .fontSize(13)
                    .backgroundColor(Theme.bg)
                    .borderRadius(8)
                    .layoutWeight(1)
                    .onChange((v: string): void => {
                      this.phone = v;
                    })
                  Text(this.countdown > 0 ? `${this.countdown}s后重发` : '获取验证码')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.countdown > 0 ? Theme.sub : Color.White)
                    .backgroundColor(this.countdown > 0 ? Theme.bg : Theme.primary)
                    .borderRadius(8)
                    .height(40)
                    .padding({ left: 12, right: 12 })
                    .margin({ left: 8 })
                    .textAlign(TextAlign.Center)
                    .onClick((): void => {
                      this.sendCode();
                    })
                }
                .width('100%')

                Text('短信验证码')
                  .fontSize(13)
                  .fontColor(Theme.sub)
                  .margin({ top: 10, bottom: 4 })
                TextInput({ placeholder: '6位数字验证码', text: this.smsCode })
                  .height(40)
                  .fontSize(13)
                  .backgroundColor(Theme.bg)
                  .borderRadius(8)
                  .onChange((v: string): void => {
                    this.smsCode = v;
                  })

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
              Text('· 买卖双方均为实名认证在校学生，从源头减少校外诈骗')
                .fontSize(12).fontColor(Theme.sub).width('100%')
              Text('· 认证后才能发布、接单、私聊，浏览不受限')
                .fontSize(12).fontColor(Theme.sub).width('100%')
              Text('· 手机号仅用于短信验证码核验身份，脱敏存储（如 138****5678）')
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
