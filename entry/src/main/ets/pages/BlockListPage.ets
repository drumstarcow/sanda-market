// 黑名单管理：解除拉黑
import { store } from '../common/AppStore';
import { Theme } from '../common/Theme';
import { User } from '../model/Models';
import { Avatar, EmptyTip, PageHeader } from '../views/Widgets';

@ComponentV2
export struct BlockListPage {
  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
  }

  private userOf(id: string): User {
    const u = store.users.find((x: User): boolean => x.id === id);
    const fb = new User();
    fb.id = id;
    fb.nickname = '杉达同学';
    return u === undefined ? fb : u;
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({
          title: '黑名单管理',
          onBack: (): void => {
            store.nav.pop();
          }
        })

        Text('拉黑后对方的所有消息不再送达，你可以随时在这里解除。')
          .fontSize(11)
          .fontColor(Theme.sub)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })

        if (store.blacklist.length === 0) {
          Column() {
            EmptyTip({ text: '未拉黑任何用户' })
          }
          .layoutWeight(1)
          .width('100%')
        } else {
          List({ space: 10 }) {
            ForEach(store.blacklist, (id: string) => {
              ListItem() {
                Row({ space: 10 }) {
                  Avatar({ name: this.userOf(id).nickname, hue: this.userOf(id).hue, dim: 40 })
                  Column({ space: 3 }) {
                    Text(this.userOf(id).nickname)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Theme.text)
                    Text('消息已不再送达')
                      .fontSize(11)
                      .fontColor(Theme.sub)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text('解除拉黑')
                    .fontSize(12)
                    .fontColor(Theme.primary)
                    .border({ width: 1, color: Theme.primary })
                    .borderRadius(14)
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .onClick(() => {
                      store.unblockPeer(id).then((err: string): void => {
                        this.toast(err.length > 0 ? err : '已解除拉黑');
                      });
                    })
                }
                .width('100%')
                .padding(12)
                .backgroundColor(Theme.card)
                .borderRadius(12)
                .alignItems(VerticalAlign.Center)
              }
            }, (id: string) => id + store.blacklist.length.toString())
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 12 })
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg)
    }
    .hideTitleBar(true)
  }
}
