// 聊天：个人信息自动隐藏 · 单方面拒聊 · 拉黑 · 举报 · 面交安全提示
import { store } from '../common/AppStore';
import { SensitiveFilter, SensitiveHit } from '../common/SensitiveFilter';
import { Theme } from '../common/Theme';
import { ChatMessage, ChatSession, MsgKind, SessionState, User } from '../model/Models';
import { Avatar, TagBadge, PageHeader } from '../views/Widgets';

@ComponentV2
export struct ChatPage {
  @Local input: string = '';
  @Local showSheet: boolean = false;
  private scroller: Scroller = new Scroller();
  private fallbackSession: ChatSession = new ChatSession();
  private fallbackUser: User = new User();
  private timerId: number = -1;
  private lastCount: number = 0;
  private sending: boolean = false;

  private s(): ChatSession {
    const r = store.findSession(store.pendingChatId);
    return r === undefined ? this.fallbackSession : r;
  }

  private exists(): boolean {
    return store.findSession(store.pendingChatId) !== undefined;
  }

  private peer(): User {
    const u = store.users.find((x: User): boolean => x.id === this.s().peerId);
    return u === undefined ? this.fallbackUser : u;
  }

  private hits(): SensitiveHit[] {
    return SensitiveFilter.detect(this.input);
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
  }

  private countNow(): number {
    const sess = store.findSession(store.pendingChatId);
    return sess === undefined ? 0 : sess.messages.length;
  }

  // 轮询回来后若消息数变化则滚动到底部
  private checkGrew(): void {
    const n = this.countNow();
    if (n !== this.lastCount) {
      this.lastCount = n;
      this.scrollBottom();
    }
  }

  private syncNow(): void {
    store.refreshSession(store.pendingChatId).then((): void => {
      this.checkGrew();
    });
  }

  aboutToAppear(): void {
    this.lastCount = this.countNow();
    this.syncNow();
    this.timerId = setInterval((): void => {
      this.syncNow();
    }, 2500);
    setTimeout((): void => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 100);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private scrollBottom(): void {
    setTimeout((): void => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 60);
  }

  private send(): void {
    const text = this.input.trim();
    if (text.length === 0 || this.sending) {
      return;
    }
    if (this.s().state !== SessionState.Active) {
      this.toast('当前会话无法发送消息');
      return;
    }
    const had = this.hits().length > 0;
    this.sending = true;
    store.sendMessage(store.pendingChatId, text).then((err: string): void => {
      this.sending = false;
      if (err.length > 0) {
        this.toast(err);
        return;
      }
      this.input = '';
      this.checkGrew();
      if (had) {
        this.toast('已自动隐藏联系方式后发送');
      }
    });
  }

  private refuse(): void {
    store.refuseSession(store.pendingChatId).then((_err: string): void => {
      this.showSheet = false;
      this.toast('已单方面拒绝此会话，对方消息不再送达');
    });
  }

  private block(): void {
    this.showSheet = false;
    this.getUIContext().showAlertDialog({
      title: '拉黑该用户',
      message: '拉黑后双方消息均不再送达，可随时在「我的-黑名单管理」解除。',
      primaryButton: {
        value: '取消',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '拉黑',
        fontColor: Theme.danger,
        action: (): void => {
          store.blockPeer(this.peer().id).then((err: string): void => {
            this.toast(err.length > 0 ? err : '已拉黑');
          });
        }
      }
    });
  }

  private report(): void {
    this.showSheet = false;
    this.getUIContext().showAlertDialog({
      title: '举报该用户',
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
          store.reportPeer(this.peer().id, '涉嫌骚扰或欺诈').then((err: string): void => {
            this.toast(err.length > 0 ? err : '已收到举报，平台将在24小时内核实处理');
          });
        }
      }
    });
  }

  private demoMsg(): void {
    store.demoMessage(store.pendingChatId).then((_err: string): void => {
      this.showSheet = false;
      this.checkGrew();
    });
  }

  @Builder
  StateBanner() {
    if (this.s().state === SessionState.RefusedByMe) {
      Row({ space: 8 }) {
        Text('你已单方面拒绝此会话，对方的新消息不再送达')
          .fontSize(12)
          .fontColor(Theme.warn)
          .layoutWeight(1)
        Text('恢复接收')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.primary)
          .onClick(() => {
            store.resumeSession(store.pendingChatId);
          })
      }
      .width('100%')
      .padding(10)
      .backgroundColor(Theme.warnSoft)
      .borderRadius(10)
    } else if (this.s().state === SessionState.BlockedByMe) {
      Row({ space: 8 }) {
        Text('已拉黑该用户，双方消息均不再送达')
          .fontSize(12)
          .fontColor(Theme.danger)
          .layoutWeight(1)
        Text('解除拉黑')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.primary)
          .onClick(() => {
            store.unblockPeer(this.peer().id);
            this.toast('已解除拉黑');
          })
      }
      .width('100%')
      .padding(10)
      .backgroundColor(Theme.dangerSoft)
      .borderRadius(10)
    } else if (this.s().state === SessionState.RefusedByPeer) {
      Text('对方已拒绝此会话，消息无法送达')
        .fontSize(12)
        .fontColor(Theme.sub)
        .width('100%')
        .padding(10)
        .backgroundColor(Theme.bg)
        .borderRadius(10)
    }
  }

  @Builder
  Bubble(m: ChatMessage) {
    if (m.kind === MsgKind.System) {
      Row() {
        Text(m.text)
          .fontSize(11)
          .fontColor(Theme.sub)
          .textAlign(TextAlign.Center)
          .backgroundColor(Theme.bg)
          .padding(8)
          .borderRadius(8)
          .constraintSize({ maxWidth: '86%' })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 6, bottom: 6 })
    } else {
      Row() {
        Column({ space: 3 }) {
          Text(m.text)
            .fontSize(14)
            .fontColor(m.fromMe ? Color.White : Theme.text)
            .lineHeight(20)
        }
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor(m.fromMe ? Theme.primary : Theme.card)
        .borderRadius(12)
        .constraintSize({ maxWidth: '74%' })
        .alignItems(HorizontalAlign.Start)

        if (m.kind === MsgKind.Masked) {
          Text('已隐藏联系方式')
            .fontSize(9)
            .fontColor(Theme.warn)
        }
      }
      .width('100%')
      .justifyContent(m.fromMe ? FlexAlign.End : FlexAlign.Start)
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 6 })
    }
  }

  @Builder
  MenuSheet() {
    Column({ space: 4 }) {
      Text('会话管理')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.text)
        .padding(12)

      Text('单方面拒绝聊天')
        .fontSize(14)
        .fontColor(Theme.text)
        .width('100%')
        .padding(13)
        .onClick(() => {
          this.refuse();
        })

      Divider().color(Theme.line).height(1)

      Text('拉黑该用户')
        .fontSize(14)
        .fontColor(Theme.danger)
        .width('100%')
        .padding(13)
        .onClick(() => {
          this.block();
        })

      Divider().color(Theme.line).height(1)

      Text('举报该用户')
        .fontSize(14)
        .fontColor(Theme.danger)
        .width('100%')
        .padding(13)
        .onClick(() => {
          this.report();
        })

      Divider().color(Theme.line).height(1)

      Text('模拟对方消息（演示隐私过滤）')
        .fontSize(14)
        .fontColor(Theme.blue)
        .width('100%')
        .padding(13)
        .onClick(() => {
          this.demoMsg();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({
          title: this.exists() ? this.peer().nickname : '会话',
          onBack: (): void => {
            store.nav.pop();
          }
        })

        if (!this.exists()) {
          Column() {
            Text('会话不存在').fontSize(13).fontColor(Theme.sub)
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          // 对方信息 + 安全说明
          Row({ space: 8 }) {
            Avatar({ name: this.peer().nickname, hue: this.peer().hue, dim: 30 })
            Text(`${this.peer().college} · 信用分 ${this.peer().credit} · ${store.creditLevel(this.peer().credit)}`)
              .fontSize(11)
              .fontColor(Theme.sub)
              .layoutWeight(1)
              .maxLines(1)
            if (this.peer().verified) {
              TagBadge({ label: '杉达认证' })
            }
            Text('⋯')
              .fontSize(16)
              .fontColor(Theme.text)
              .width(32)
              .height(28)
              .textAlign(TextAlign.Center)
              .backgroundColor(Theme.card)
              .borderRadius(8)
              .onClick(() => {
                this.showSheet = true;
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 6 })

          Text('聊天中的联系方式已自动隐藏 · 觉得不合理可随时拒聊或拉黑')
            .fontSize(10)
            .fontColor(Theme.sub)
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 6 })

          this.StateBanner()

          // 消息列表
          List({ space: 0, scroller: this.scroller }) {
            ForEach(this.s().messages, (m: ChatMessage) => {
              ListItem() {
                this.Bubble(m)
              }
            }, (m: ChatMessage) => m.id)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 16, right: 16, top: 6 })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)

          // 输入区
          if (this.s().state === SessionState.Active) {
            Column({ space: 4 }) {
              if (this.hits().length > 0) {
                Text(`检测到个人信息（${SensitiveFilter.hintOf(this.hits())}），发送后将自动隐藏`)
                  .fontSize(11)
                  .fontColor(Theme.warn)
                  .width('100%')
              }
              Row({ space: 8 }) {
                TextInput({ placeholder: '输入消息…', text: this.input })
                  .height(40)
                  .fontSize(14)
                  .backgroundColor(Theme.card)
                  .borderRadius(20)
                  .layoutWeight(1)
                  .onChange((v: string): void => {
                    this.input = v;
                  })
                  .onSubmit((): void => {
                    this.send();
                  })
                Text('发送')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .backgroundColor(Theme.primary)
                  .borderRadius(20)
                  .height(40)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => {
                    this.send();
                  })
              }
              .width('100%')
            }
            .padding({ left: 16, right: 16, top: 6, bottom: 12 })
            .width('100%')
            .backgroundColor(Theme.bg)
          } else {
            Text('会话已关闭，无法收发消息')
              .fontSize(12)
              .fontColor(Theme.sub)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(14)
          }
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg)
    }
    .hideTitleBar(true)
    .bindSheet(this.showSheet, this.MenuSheet(), {
      height: 300,
      onDisappear: (): void => {
        this.showSheet = false;
      }
    })
  }
}
