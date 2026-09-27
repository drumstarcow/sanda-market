// 数据模型：杉达集市（上海杉达学院校园交易市场）

@ObservedV2
export class User {
  @Trace id: string = '';
  @Trace nickname: string = '';
  @Trace college: string = '';
  @Trace verified: boolean = false;
  @Trace credit: number = 90;
  @Trace studentNoMasked: string = '';
  @Trace hue: string = '#0A9F58';
}

export enum GoodsKind {
  Textbook = 0,
  Errand = 1,
  Help = 2
}

export enum ErrandType {
  Express = 0, // 快递代拿
  Takeout = 1, // 外卖跑腿
  Canteen = 2 // 食堂代选
}

export enum BookCondition {
  New = 0,
  LikeNew = 1,
  Good = 2,
  Worn = 3
}

export function condLabel(c: BookCondition): string {
  switch (c) {
    case BookCondition.New:
      return '全新';
    case BookCondition.LikeNew:
      return '九成新';
    case BookCondition.Good:
      return '八成新';
    case BookCondition.Worn:
      return '明显使用';
    default:
      return '八成新';
  }
}

// 跑腿订单参数（份数 / 快递大小 / 重量，用于公平计价）
@ObservedV2
export class ErrandInfo {
  @Trace type: ErrandType = ErrandType.Express;
  @Trace pieces: number = 1;
  @Trace size: string = 'M';
  @Trace weightKg: number = 0;
  @Trace fromPoint: string = '';
  @Trace toPoint: string = '';
  @Trace dishes: string[] = [];
  @Trace taste: string = '';
}

@ObservedV2
export class GoodsItem {
  @Trace id: string = '';
  @Trace kind: GoodsKind = GoodsKind.Textbook;
  @Trace title: string = '';
  @Trace desc: string = '';
  @Trace price: number = 0;
  @Trace course: string = '';
  @Trace condition: BookCondition = BookCondition.Good;
  @Trace errand: ErrandInfo = new ErrandInfo();
  @Trace sellerId: string = '';
  @Trace timeText: string = '';
  @Trace wanted: boolean = false;
  @Trace reward: number = 0;
}

export enum MsgKind {
  Normal = 0,
  Masked = 1, // 含个人信息，已被平台自动隐藏
  System = 2
}

@ObservedV2
export class ChatMessage {
  @Trace id: string = '';
  @Trace fromMe: boolean = false;
  @Trace text: string = '';
  @Trace kind: MsgKind = MsgKind.Normal;
  @Trace timeText: string = '';
}

export enum SessionState {
  Active = 0,
  RefusedByMe = 1, // 我单方面拒绝了聊天
  RefusedByPeer = 2, // 对方拒绝了聊天
  BlockedByMe = 3, // 我拉黑了对方
  BlockedByPeer = 4
}

export function sessionStateLabel(s: SessionState): string {
  switch (s) {
    case SessionState.RefusedByMe:
      return '已拒收';
    case SessionState.RefusedByPeer:
      return '对方已拒收';
    case SessionState.BlockedByMe:
      return '已拉黑';
    case SessionState.BlockedByPeer:
      return '无法送达';
    default:
      return '';
  }
}

@ObservedV2
export class ChatSession {
  @Trace id: string = '';
  @Trace peerId: string = '';
  @Trace goodsId: string = '';
  @Trace messages: ChatMessage[] = [];
  @Trace state: SessionState = SessionState.Active;
}

@ObservedV2
export class ReportItem {
  @Trace id: string = '';
  @Trace targetId: string = '';
  @Trace targetName: string = '';
  @Trace reason: string = '';
  @Trace timeText: string = '';
}

export interface FeeRow {
  label: string;
  amount: number;
}
