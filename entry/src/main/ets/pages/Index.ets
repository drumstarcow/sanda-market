// 入口：四 Tab（集市 / 发布 / 消息 / 我的）+ Navigation 子页路由 + 首启隐私协议遮罩
import { common } from '@kit.AbilityKit';
import { store } from '../common/AppStore';
import { Theme } from '../common/Theme';
import { BlockListPage } from './BlockListPage';
import { CertifyPage } from './CertifyPage';
import { ChatPage } from './ChatPage';
import { DetailPage } from './DetailPage';
import { HomePage } from './HomePage';
import { MessagePage } from './MessagePage';
import { MinePage } from './MinePage';
import { PublishPage } from './PublishPage';

const PRIVACY_TEXT: string =
  '欢迎使用杉达集市（上海杉达学院校园生活交易市场）。在使用前，请阅读并同意本隐私政策：\n\n' +
  '一、我们收集的信息\n' +
  '1. 账户信息：首次启动时自动生成的随机昵称与用户编号，不含您的真实身份；\n' +
  '2. 认证信息（可选）：当您申请"本校学生认证"时提交的姓名、学号、学院。学号仅脱敏存储并展示（如 23****17），不会向其他用户透露完整内容；\n' +
  '3. 发布与聊天内容：您发布的商品、跑腿、求助信息及聊天消息。系统会自动检测并隐藏手机号、微信号、QQ号、银行卡号、学号等个人联系方式；\n' +
  '4. 安全操作记录：拒聊、拉黑、举报等用于维护平台信任的操作。\n\n' +
  '二、信息用途\n' +
  '上述信息仅用于提供校内二手教材交易、跑腿代拿、食堂代选、求助互助及聊天服务，以及信用分、举报处理等平台安全管理，不用于任何其他目的。\n\n' +
  '三、存储与共享\n' +
  '数据存储于本课程演示所使用的服务器，不向境外传输；除法律法规要求外，我们不会向任何第三方提供您的个人信息。\n\n' +
  '四、您的权利\n' +
  '您可以随时拒聊、拉黑任意用户，或对违规行为进行举报；如需删除账号及全部数据，可通过本页"联系管理员"申请。\n\n' +
  '五、使用规范\n' +
  '本服务仅面向上海杉达学院校内交流场景，请遵守国家法律法规与校园规范，拒绝私下转账与校外代购等风险行为。\n\n' +
  '若您不同意本政策，我们将无法为您提供上述服务，您可以退出本应用。';

@Entry
@ComponentV2
struct Index {
  @Local curTab: number = 0;

  aboutToAppear(): void {
    store.checkPrivacy();
    if (!store.showPrivacy) {
      store.init(); // 已同意过才联网初始化
    }
  }

  private refusePrivacy(): void {
    const host = this.getUIContext().getHostContext();
    if (host) {
      (host as common.UIAbilityContext).terminateSelf();
    }
  }

  private onAgree(): void {
    const first: boolean = !store.privacyViewOnly;
    store.agreePrivacy();
    if (first) {
      store.init(); // 同意后才联网注册/拉取数据
    }
  }

  @Builder
  PageMap(name: string) {
    if (name === 'detail') {
      DetailPage()
    } else if (name === 'chat') {
      ChatPage()
    } else if (name === 'certify') {
      CertifyPage()
    } else if (name === 'blocks') {
      BlockListPage()
    }
  }

  @Builder
  TabItem(index: number, label: string) {
    Column() {
      Text(label)
        .fontSize(11)
        .fontWeight(this.curTab === index ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(this.curTab === index ? Theme.primary : Theme.sub)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  // 首次启动隐私协议遮罩（审核要求：首次进入必须先展示隐私协议）
  @Builder
  PrivacyCover() {
    Column() {
      Column() {
        Text('隐私政策')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.text)
          .margin({ bottom: 12 })

        Scroll() {
          Text(PRIVACY_TEXT)
            .fontSize(13)
            .fontColor(Theme.sub)
            .lineHeight(20)
            .width('100%')
        }
        .constraintSize({ minHeight: 120, maxHeight: 320 })
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)

        Text('联系管理员：13601785818@139.com')
          .fontSize(11)
          .fontColor(Theme.sub)
          .margin({ top: 8, bottom: 14 })

        if (store.privacyViewOnly) {
          // 已同意用户：仅查看
          Text('我知道了')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(Theme.primary)
            .borderRadius(22)
            .width('100%')
            .height(44)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              store.showPrivacy = false;
            })
        } else {
          // 首次启动：必须做出选择
          Row({ space: 12 }) {
            Text('不同意并退出')
              .fontSize(14)
              .fontColor(Theme.sub)
              .backgroundColor(Theme.bg)
              .borderRadius(22)
              .layoutWeight(1)
              .height(44)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.refusePrivacy();
              })
            Text('同意并继续')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor(Theme.primary)
              .borderRadius(22)
              .layoutWeight(1)
              .height(44)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.onAgree();
              })
          }
          .width('100%')
        }
      }
      .padding(20)
      .backgroundColor(Theme.card)
      .borderRadius(16)
      .width('86%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.55)')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack() {
      Navigation(store.nav) {
        Tabs({ barPosition: BarPosition.End, index: this.curTab, controller: store.ctrl }) {
          TabContent() {
            HomePage()
          }
          .tabBar(this.TabItem(0, '集市'))

          TabContent() {
            PublishPage()
          }
          .tabBar(this.TabItem(1, '发布'))

          TabContent() {
            MessagePage()
          }
          .tabBar(this.TabItem(2, '消息'))

          TabContent() {
            MinePage()
          }
          .tabBar(this.TabItem(3, '我的'))
        }
        .onChange((index: number) => {
          this.curTab = index;
        })
        .layoutWeight(1)
      }
      .navDestination(this.PageMap)
      .mode(NavigationMode.Stack)
      .hideTitleBar(true)
      .hideToolBar(true)
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg)

      if (store.showPrivacy) {
        this.PrivacyCover()
      }
    }
    .width('100%')
    .height('100%')
  }
}
