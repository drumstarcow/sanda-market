// 我的：认证状态 / 信用分 / 黑名单 / 举报记录 / 安全须知
import { store } from '../common/AppStore';
import { Theme } from '../common/Theme';
import { ReportItem } from '../model/Models';
import { Avatar, TagBadge, EmptyTip } from '../views/Widgets';

@ComponentV2
export struct MinePage {
  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
  }

  @Builder
  ActionRow(label: string, value: string, onTap: () => void) {
    Row() {
      Text(label).fontSize(14).fontColor(Theme.text)
      Blank()
      Text(value).fontSize(12).fontColor(Theme.sub)
      Text('›').fontSize(14).fontColor(Theme.sub).margin({ left: 6 })
    }
    .width('100%')
    .padding(14)
    .onClick(() => {
      onTap();
    })
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        // 个人卡片
        Column({ space: 10 }) {
          Row({ space: 12 }) {
            Avatar({ name: store.me.nickname, hue: store.me.hue, dim: 52 })
            Column({ space: 4 }) {
              Row({ space: 6 }) {
                Text(store.me.nickname)
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Theme.text)
                if (store.me.verified) {
                  TagBadge({ label: '杉达认证' })
                } else {
                  TagBadge({ label: '未认证', fg: Theme.warn, bg: Theme.warnSoft })
                }
              }
              Text(store.me.verified
                ? `${store.me.college} · 学号 ${store.me.studentNoMasked}`
                : '完成学生认证后可发布、接单、私聊')
                .fontSize(12)
                .fontColor(Theme.sub)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Row() {
            Column({ space: 2 }) {
              Text(`${store.me.credit}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.primary)
              Text(store.creditLevel(store.me.credit)).fontSize(10).fontColor(Theme.sub)
            }
            .layoutWeight(1)

            Column({ space: 2 }) {
              Text(`${store.goods.filter((g): boolean => g.sellerId === store.me.id).length}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.text)
              Text('我的发布').fontSize(10).fontColor(Theme.sub)
            }
            .layoutWeight(1)

            Column({ space: 2 }) {
              Text(`${store.blacklist.length}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.text)
              Text('黑名单').fontSize(10).fontColor(Theme.sub)
            }
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 8 })

          if (!store.me.verified) {
            Text('立即完成杉达学生认证')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor(Theme.primary)
              .borderRadius(20)
              .width('100%')
              .height(40)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                store.go('certify');
              })
          }
        }
        .padding(14)
        .backgroundColor(Theme.card)
        .borderRadius(12)
        .width('100%')

        // 功能入口
        Column() {
          this.ActionRow('我的发布', '集市中查看', (): void => {
            this.toast(`你共发布 ${store.goods.filter((g): boolean => g.sellerId === store.me.id).length} 件内容`);
          })
          Divider().color(Theme.line).height(1)
          this.ActionRow('黑名单管理', `${store.blacklist.length} 人`, (): void => {
            store.go('blocks');
          })
          Divider().color(Theme.line).height(1)
          this.ActionRow('学生认证', store.me.verified ? '已认证' : '未认证', (): void => {
            store.go('certify');
          })
          Divider().color(Theme.line).height(1)
          this.ActionRow('隐私政策', '查看', (): void => {
            store.viewPrivacy();
          })
        }
        .backgroundColor(Theme.card)
        .borderRadius(12)
        .width('100%')
        .clip(true)

        // 举报记录
        Column({ space: 8 }) {
          Text('举报记录')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.text)
            .width('100%')
          if (store.reports.length === 0) {
            Text('暂无举报记录').fontSize(12).fontColor(Theme.sub).width('100%')
          } else {
            ForEach(store.reports, (r: ReportItem) => {
              Row() {
                Column({ space: 2 }) {
                  Text(`举报「${r.targetName}」`)
                    .fontSize(13)
                    .fontColor(Theme.text)
                  Text(`${r.reason} · ${r.timeText}`)
                    .fontSize(11)
                    .fontColor(Theme.sub)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                TagBadge({ label: '平台核实中', fg: Theme.warn, bg: Theme.warnSoft })
              }
              .width('100%')
              .padding(10)
              .backgroundColor(Theme.bg)
              .borderRadius(8)
            }, (r: ReportItem) => r.id)
          }
        }
        .padding(14)
        .backgroundColor(Theme.card)
        .borderRadius(12)
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // 安全须知
        Column({ space: 8 }) {
          Text('安全与信任规则')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.text)
            .width('100%')
          Text('1. 仅限杉达学生认证用户发布、接单与私聊。')
            .fontSize(12).fontColor(Theme.sub).width('100%')
          Text('2. 聊天与发布内容中的手机号、微信、QQ、学号、银行卡会被自动隐藏。')
            .fontSize(12).fontColor(Theme.sub).width('100%')
          Text('3. 任何一方觉得交易不合理，可单方面拒绝聊天；拉黑后对方消息不再送达。')
            .fontSize(12).fontColor(Theme.sub).width('100%')
          Text('4. 面交请选择食堂门口、宿舍楼大厅等人多的公共场所，当面验货。')
            .fontSize(12).fontColor(Theme.sub).width('100%')
          Text('5. 平台与卖家不会以任何理由索要验证码或要求脱离平台转账，谨防诈骗。')
            .fontSize(12).fontColor(Theme.sub).width('100%')
          Text('6. 信用分：初始90，完成交易+2，被举报核实-2，恶意爽约-10。')
            .fontSize(12).fontColor(Theme.sub).width('100%')
        }
        .padding(14)
        .backgroundColor(Theme.card)
        .borderRadius(12)
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .padding(16)
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
    .align(Alignment.Top)
  }
}
