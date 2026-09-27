// 消息：会话列表（状态标识：已拒收 / 已拉黑）
import { store } from '../common/AppStore';
import { Theme } from '../common/Theme';
import { ChatSession, MsgKind, SessionState, sessionStateLabel } from '../model/Models';
import { Avatar, TagBadge, EmptyTip } from '../views/Widgets';

@ComponentV2
export struct MessagePage {
  private stateColor(s: SessionState): string {
    if (s === SessionState.BlockedByMe) {
      return Theme.danger;
    }
    if (s === SessionState.Active) {
      return Theme.primary;
    }
    return Theme.warn;
  }

  private preview(s: ChatSession): string {
    if (s.messages.length === 0) {
      return '发起沟通吧';
    }
    const last = s.messages[s.messages.length - 1];
    if (last.kind === MsgKind.System) {
      return `[系统] ${last.text}`;
    }
    return (last.fromMe ? '我：' : '') + last.text;
  }

  private timerId: number = -1;

  aboutToAppear(): void {
    store.refreshSessions();
    this.timerId = setInterval((): void => {
      store.refreshSessions();
    }, 5000);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  build() {
    Column() {
      Column({ space: 4 }) {
        Text('消息')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.text)
          .width('100%')
        Text('平台已自动隐藏聊天中的联系方式 · 可随时拒聊或拉黑')
          .fontSize(11)
          .fontColor(Theme.sub)
          .width('100%')
      }
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .width('100%')

      if (store.sessions.length === 0) {
        Column() {
          EmptyTip({ text: '暂无会话，去集市逛逛吧' })
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        List({ space: 10 }) {
          ForEach(store.sessions, (s: ChatSession) => {
            ListItem() {
              Row({ space: 10 }) {
                Avatar({
                  name: store.findUser(s.peerId).nickname,
                  hue: store.findUser(s.peerId).hue,
                  dim: 44
                })
                Column({ space: 4 }) {
                  Row({ space: 6 }) {
                    Text(store.findUser(s.peerId).nickname)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Theme.text)
                      .maxLines(1)
                    if (store.findUser(s.peerId).verified) {
                      TagBadge({ label: '杉达认证' })
                    }
                    Text(`信用分 ${store.findUser(s.peerId).credit}`)
                      .fontSize(10)
                      .fontColor(Theme.sub)
                  }
                  Text(this.preview(s))
                    .fontSize(12)
                    .fontColor(Theme.sub)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (s.state !== SessionState.Active) {
                  TagBadge({
                    label: sessionStateLabel(s.state),
                    fg: this.stateColor(s.state),
                    bg: s.state === SessionState.BlockedByMe ? Theme.dangerSoft : Theme.warnSoft
                  })
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(Theme.card)
              .borderRadius(12)
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                store.openChat(s.id);
              })
            }
          }, (s: ChatSession) => s.id + s.state.toString() + s.messages.length.toString())
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
