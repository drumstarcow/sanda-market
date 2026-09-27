// 入口：四 Tab（集市 / 发布 / 消息 / 我的）+ Navigation 子页路由
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

@Entry
@ComponentV2
struct Index {
  @Local curTab: number = 0;

  aboutToAppear(): void {
    store.init();
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

  build() {
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
  }
}
