// 学生认证：实名核验 + 学号校验 + 学院选择（学号/手机号均脱敏存储与展示）
// 核验模式由服务端下发（store.authMode）：
//   pnvs = 运营商本机号码校验（真机，SDK 拉起运营商授权确认）
//   mock = 短信验证码调试路径（模拟器无 SIM 卡时使用）
import PhoneNumberAuthHelper from 'numberauth_standard';
import { TokenResultListener } from 'numberauth_standard';
import { common } from '@kit.AbilityKit';
import { store } from '../common/AppStore';
import { Theme } from '../common/Theme';
import { Chip, PageHeader } from '../views/Widgets';

// 阿里云号码认证方案密钥（控制台-认证方案管理-方案详情）
const PNVS_SECRET_KEY: string = '2+r2dP+PHJAs/CtOzFuLSjz/M1Zb2rAHWgEv58+vVqm6GZ3DRW3/hh+P2gGd9bkVhqBkBRG+yqOA3wCQrJeuWhpVk8Z/8BUP8SOYYpONBOllw3k+g8yogIgahwwhrNCNYzsUkN+0Wo5JoicBIIZUwjqZsNeyIOzlMWo205evJbUuMk/MM/hg87UBHV9Gw6ycgiFIBuq4XwcI/aiy2lenZi7SUwjOBbfxb97Ars+L/2U8GkhYbFwfE1e7ZQm4sCW/XPIPxJWRzTOHY4zsVhfZanFP/CNxvVP7uyp/mBLHt0I7wHrkACWf74CDqrs01sWXUBW+Xj/kYEZqKof1IVjVOMheFMJB8cfQ+rC8XZA3gVEMzK1mrIg/8uvzP7amYRvd';

// 运营商校验回调桥接：SDK 接口回调 → 页面处理
class PnvsTokenListener implements TokenResultListener {
  private page: CertifyPage;

  constructor(page: CertifyPage) {
    this.page = page;
  }

  onSuccess(msg: string): void {
    console.info('[pnvs] onSuccess: ' + msg);
    this.page.handlePnvsResult(msg);
  }

  onFailure(ret: string): void {
    console.error('[pnvs] onFailure: ' + ret);
    this.page.handlePnvsFailure('本机校验未完成，请在插入SIM卡的真机上重试');
  }
}

@ComponentV2
export struct CertifyPage {
  @Local name: string = '';
  @Local studentNo: string = '';
  @Local college: string = '';
  @Local phone: string = '';
  @Local smsCode: string = '';
  @Local countdown: number = 0;
  @Local verifying: boolean = false;
  private timerId: number = -1;
  private helper: PhoneNumberAuthHelper | undefined = undefined;
  readonly colleges: string[] = [
    '信息科学与技术学院', '商学院', '教育学院', '艺术设计学院', '护理学院', '国际医学院'
  ];

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.helper !== undefined) {
      this.helper.setAuthListener(undefined);
      this.helper = undefined;
    }
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2500 });
  }

  // ---------------- mock：短信验证码（模拟器调试路径） ----------------
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

  // ---------------- 共用格式校验 ----------------
  private validateBasic(): boolean {
    if (!/^1[3-9]\d{9}$/.test(this.phone.trim())) {
      this.toast('请输入正确的11位手机号');
      return false;
    }
    if (this.name.trim().length < 2 || this.name.trim().length > 20) {
      this.toast('请输入真实姓名（2-20个字符）');
      return false;
    }
    if (!/^\d{8,12}$/.test(this.studentNo.trim())) {
      this.toast('学号需为8-12位数字，请核对后重试');
      return false;
    }
    if (this.college.length === 0) {
      this.toast('请选择所在学院');
      return false;
    }
    return true;
  }

  // ---------------- mock 提交（验证码） ----------------
  private submitMock(): void {
    if (this.smsCode.trim().length !== 6) {
      this.toast('请输入6位短信验证码');
      return;
    }
    store.certify(this.name.trim(), this.studentNo.trim(), this.college, this.phone.trim(), this.smsCode.trim(), false)
      .then((err: string): void => {
        if (err.length === 0) {
          this.toast('认证通过，欢迎加入杉集');
          store.nav.pop();
        } else {
          this.toast(err);
        }
      });
  }

  // ---------------- pnvs：运营商本机号码校验（真机） ----------------
  private submitPnvs(): void {
    if (!this.validateBasic()) {
      return;
    }
    if (this.verifying) {
      return;
    }
    this.verifying = true;
    this.toast('正在拉起运营商本机校验…');
    const listener = new PnvsTokenListener(this);
    const ctx = getContext(this) as common.Context;
    this.helper = PhoneNumberAuthHelper.getInstance(ctx, listener);
    this.helper.setAuthSDKInfo(PNVS_SECRET_KEY).then((): void => {
      if (this.helper !== undefined) {
        this.helper.getVerifyToken(6000);
      }
    }).catch((): void => {
      this.handlePnvsFailure('校验初始化失败，请重试');
    });
  }

  handlePnvsResult(msg: string): void {
    let code: string = '';
    let token: string = '';
    try {
      const obj = JSON.parse(msg) as Record<string, Object>;
      code = String(obj['_code'] ?? '');
      token = String(obj['_token'] ?? '');
    } catch (e) {
      this.handlePnvsFailure('本机校验返回异常，请重试');
      return;
    }
    if (code !== '600000' || token.length === 0) {
      // 600004=无法获取本机号码（无SIM卡/非蜂窝设备），600013=运营商不支持等
      this.handlePnvsFailure(code === '600004'
        ? '未检测到本机SIM卡，请用插入SIM卡的真机完成实名核验'
        : '本机校验未完成（' + code + '），请重试');
      return;
    }
    // token 交给服务端向阿里云核验手机号一致性
    store.certify(this.name.trim(), this.studentNo.trim(), this.college, this.phone.trim(), token, true)
      .then((err: string): void => {
        this.verifying = false;
        if (err.length === 0) {
          this.toast('实名核验通过，欢迎加入杉集');
          store.nav.pop();
        } else {
          this.toast(err);
        }
      });
  }

  handlePnvsFailure(msg: string): void {
    this.verifying = false;
    if (this.helper !== undefined) {
      this.helper.setAuthListener(undefined);
    }
    this.toast(msg);
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
                TextInput({ placeholder: '11位手机号', text: this.phone })
                  .type(InputType.PhoneNumber)
                  .height(40)
                  .fontSize(13)
                  .backgroundColor(Theme.bg)
                  .borderRadius(8)
                  .width('100%')
                  .onChange((v: string): void => {
                    this.phone = v;
                  })

                if (store.authMode === 'pnvs') {
                  Text('提交后将拉起运营商本机号码校验，请确保本机SIM卡为该手机号')
                    .fontSize(11)
                    .fontColor(Theme.sub)
                    .margin({ top: 6 })
                } else {
                  Row() {
                    Text('短信验证码')
                      .fontSize(13)
                      .fontColor(Theme.sub)
                    Blank()
                    Text(this.countdown > 0 ? `${this.countdown}s后重发` : '获取验证码')
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.countdown > 0 ? Theme.sub : Theme.primary)
                      .onClick((): void => {
                        this.sendCode();
                      })
                  }
                  .width('100%')
                  .margin({ top: 10, bottom: 4 })

                  TextInput({ placeholder: '6位数字验证码', text: this.smsCode })
                    .height(40)
                    .fontSize(13)
                    .backgroundColor(Theme.bg)
                    .borderRadius(8)
                    .onChange((v: string): void => {
                      this.smsCode = v;
                    })
                }

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

                Text(this.verifying ? '校验中…' : '提交认证')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .backgroundColor(this.verifying ? Theme.sub : Theme.primary)
                  .borderRadius(22)
                  .width('100%')
                  .height(44)
                  .textAlign(TextAlign.Center)
                  .margin({ top: 20 })
                  .onClick(() => {
                    if (!this.validateBasic()) {
                      return;
                    }
                    if (store.authMode === 'pnvs') {
                      this.submitPnvs();
                    } else {
                      this.submitMock();
                    }
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
              Text('· 手机号通过运营商本机号码核验身份，脱敏存储（如 138****5678）')
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
