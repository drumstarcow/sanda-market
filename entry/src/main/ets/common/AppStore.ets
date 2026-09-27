// 全局状态中心：服务端为主（REST），本地状态作为缓存
// 认证 / 信用分 / 黑名单 / 拒聊 / 举报 / 商品与会话
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  BlacklistResp, CertifyBody, ChatStartBody, GoodsListResp, MsgBody, PublishBody, ReportBody,
  ReportListResp, ReportResp, ServerErrand, ServerGoods, ServerMessage, ServerReport,
  ServerSession, ServerUser, SessionListResp, SessionResp, UserResp, Api
} from './Api';
import {
  BookCondition, ChatMessage, ChatSession, ErrandInfo, ErrandType, FeeRow, GoodsItem,
  GoodsKind, MsgKind, ReportItem, SessionState, User
} from '../model/Models';

export const FEE_BASE_EXPRESS = 2; // 快递代拿基础费/份
export const FEE_BASE_TAKEOUT = 2; // 外卖跑腿/份
export const FEE_BASE_CANTEEN = 3; // 食堂代选/份

// ---------------- DTO → 模型映射 ----------------
function kindOf(n: number): GoodsKind {
  if (n === 1) {
    return GoodsKind.Errand;
  }
  if (n === 2) {
    return GoodsKind.Help;
  }
  return GoodsKind.Textbook;
}

function stateOf(s: string): SessionState {
  if (s === 'refusedByMe') {
    return SessionState.RefusedByMe;
  }
  if (s === 'refusedByPeer') {
    return SessionState.RefusedByPeer;
  }
  if (s === 'blockedByMe') {
    return SessionState.BlockedByMe;
  }
  if (s === 'blockedByPeer') {
    return SessionState.BlockedByPeer;
  }
  return SessionState.Active;
}

function mapUser(su: ServerUser): User {
  const u = new User();
  u.id = su.id;
  u.nickname = su.nickname;
  u.college = su.college;
  u.verified = su.verified;
  u.credit = su.credit;
  u.studentNoMasked = su.studentNoMasked;
  u.hue = su.hue;
  return u;
}

function mapGoods(sg: ServerGoods): GoodsItem {
  const g = new GoodsItem();
  g.id = sg.id;
  g.kind = kindOf(sg.kind);
  g.title = sg.title;
  g.desc = sg.desc;
  g.price = sg.price;
  g.course = sg.course;
  g.condition = sg.condition as BookCondition;
  g.sellerId = sg.sellerId;
  g.timeText = sg.timeText;
  g.wanted = sg.wanted;
  g.reward = sg.reward;
  if (sg.errand !== null) {
    const e = new ErrandInfo();
    e.type = sg.errand.type as ErrandType;
    e.pieces = sg.errand.pieces;
    e.size = sg.errand.size;
    e.weightKg = sg.errand.weightKg;
    e.fromPoint = sg.errand.fromPoint;
    e.toPoint = sg.errand.toPoint;
    e.dishes = sg.errand.dishes.slice();
    e.taste = sg.errand.taste;
    g.errand = e;
  }
  return g;
}

function mapMessage(sm: ServerMessage, meId: string): ChatMessage {
  const m = new ChatMessage();
  m.id = sm.id;
  m.fromMe = sm.fromId === meId;
  m.text = sm.text;
  m.kind = sm.kind as MsgKind;
  m.timeText = sm.timeText;
  return m;
}

function mapSession(ss: ServerSession, meId: string): ChatSession {
  const s = new ChatSession();
  s.id = ss.id;
  s.peerId = ss.peerId;
  s.goodsId = ss.goodsId;
  s.state = stateOf(ss.state);
  const msgs: ChatMessage[] = [];
  for (const sm of ss.messages) {
    msgs.push(mapMessage(sm, meId));
  }
  s.messages = msgs;
  return s;
}

function mapReports(list: ServerReport[]): ReportItem[] {
  const out: ReportItem[] = [];
  for (const sr of list) {
    const r = new ReportItem();
    r.id = sr.id;
    r.targetId = sr.targetId;
    r.targetName = sr.targetName;
    r.reason = sr.reason;
    r.timeText = sr.timeText;
    out.push(r);
  }
  return out;
}

function toServerErrand(e: ErrandInfo): ServerErrand {
  const se: ServerErrand = {
    type: e.type,
    pieces: e.pieces,
    size: e.size,
    weightKg: e.weightKg,
    fromPoint: e.fromPoint,
    toPoint: e.toPoint,
    dishes: e.dishes.slice(),
    taste: e.taste
  };
  return se;
}

function errText(e: Object): string {
  if (e instanceof Error && e.message.length > 0) {
    return e.message;
  }
  return '网络异常，请稍后再试';
}

@ObservedV2
export class AppStore {
  // —— 身份与信任 ——
  @Trace me: User = new User();
  @Trace users: User[] = [];
  @Trace blacklist: string[] = [];
  @Trace reports: ReportItem[] = [];

  // —— 业务数据（服务端数据的本地缓存） ——
  @Trace goods: GoodsItem[] = [];
  @Trace sessions: ChatSession[] = [];
  @Trace offline: boolean = false;

  // —— 隐私协议（首次启动必须同意，审核硬性要求） ——
  @Trace showPrivacy: boolean = false; // 是否显示隐私政策遮罩
  @Trace privacyViewOnly: boolean = false; // true=已同意用户从"我的"进入仅查看

  // —— 路由 ——
  readonly nav: NavPathStack = new NavPathStack();
  readonly ctrl: TabsController = new TabsController();
  pendingDetailId: string = '';
  pendingChatId: string = '';
  pendingUserId: string = ''; // 本机保存的用户 id（EntryAbility 从 preferences 读入）
  appContext: common.Context | null = null;

  private inited: boolean = false;

  constructor() {
    this.me.nickname = '杉达同学';
  }

  // ---------------- 初始化 ----------------
  // 访客身份注册/找回 + 首屏数据拉取；失败时置 offline，可 retryInit
  async init(): Promise<void> {
    if (this.inited) {
      return;
    }
    this.inited = true;
    try {
      const r1 = await Api.guest(this.pendingUserId);
      Api.userId = r1.user.id;
      this.applyUser(r1.user);
      this.saveUserId(r1.user.id);
      const rg = await Api.getGoods();
      const goods: GoodsItem[] = [];
      for (const sg of rg.goods) {
        this.cacheUser(sg.seller);
        goods.push(mapGoods(sg));
      }
      this.goods = goods;
      const rb = await Api.getBlacklist();
      const ids: string[] = [];
      for (const su of rb.blacklist) {
        this.cacheUser(su);
        ids.push(su.id);
      }
      this.blacklist = ids;
      const rs = await Api.getSessions();
      for (const ss of rs.sessions) {
        this.cacheUser(ss.peer);
        this.ingestSession(ss);
      }
      const rr = await Api.getReports();
      this.reports = mapReports(rr.reports);
      this.offline = false;
    } catch (e) {
      this.offline = true;
    }
  }

  retryInit(): void {
    this.inited = false;
    this.init();
  }

  private saveUserId(id: string): void {
    if (this.appContext === null) {
      return;
    }
    try {
      const prefs = preferences.getPreferencesSync(this.appContext, { name: 'sanda_market' });
      prefs.putSync('userId', id);
      prefs.flush();
    } catch (e) {
    }
  }

  // ---------------- 隐私协议 ----------------
  // 启动时检查：未同意过则显示遮罩（同意后才允许 init 联网）
  checkPrivacy(): void {
    if (this.appContext === null) {
      this.privacyViewOnly = false;
      this.showPrivacy = true;
      return;
    }
    try {
      const prefs = preferences.getPreferencesSync(this.appContext, { name: 'sanda_market' });
      const agreed: boolean = prefs.getSync('privacyAgreed', false) as boolean;
      this.privacyViewOnly = agreed;
      this.showPrivacy = !agreed;
    } catch (e) {
      this.privacyViewOnly = false;
      this.showPrivacy = true;
    }
  }

  // 同意并继续：写入本地记录；之后不再弹
  agreePrivacy(): void {
    this.privacyViewOnly = true;
    this.showPrivacy = false;
    if (this.appContext === null) {
      return;
    }
    try {
      const prefs = preferences.getPreferencesSync(this.appContext, { name: 'sanda_market' });
      prefs.putSync('privacyAgreed', true);
      prefs.flush();
    } catch (e) {
    }
  }

  // "我的"页查看入口
  viewPrivacy(): void {
    this.privacyViewOnly = true;
    this.showPrivacy = true;
  }

  // ---------------- 查找 ----------------
  findUser(id: string): User {
    if (id === this.me.id) {
      return this.me;
    }
    for (const u of this.users) {
      if (u.id === id) {
        return u;
      }
    }
    const ghost = new User();
    ghost.id = id;
    ghost.nickname = '杉达同学';
    return ghost;
  }

  findGoods(id: string): GoodsItem | undefined {
    return this.goods.find((g: GoodsItem): boolean => g.id === id);
  }

  findSession(id: string): ChatSession | undefined {
    return this.sessions.find((s: ChatSession): boolean => s.id === id);
  }

  isBlocked(peerId: string): boolean {
    return this.blacklist.includes(peerId);
  }

  creditLevel(credit: number): string {
    if (credit >= 95) {
      return '信用极好';
    }
    if (credit >= 90) {
      return '信用优秀';
    }
    if (credit >= 80) {
      return '信用良好';
    }
    return '信用一般';
  }

  // ---------------- 本地缓存维护 ----------------
  private applyUser(u: ServerUser): void {
    this.me.id = u.id;
    this.me.nickname = u.nickname;
    this.me.college = u.college;
    this.me.verified = u.verified;
    this.me.credit = u.credit;
    this.me.studentNoMasked = u.studentNoMasked;
    this.me.hue = u.hue;
    this.cacheUser(u);
  }

  private cacheUser(su: ServerUser | null): void {
    if (su === null || su.id === this.me.id) {
      return;
    }
    for (const u of this.users) {
      if (u.id === su.id) {
        u.nickname = su.nickname;
        u.college = su.college;
        u.verified = su.verified;
        u.credit = su.credit;
        u.studentNoMasked = su.studentNoMasked;
        u.hue = su.hue;
        return;
      }
    }
    this.users.push(mapUser(su));
  }

  // 用服务端会话视图更新本地会话（保持对象引用稳定，保证已打开的聊天页响应式刷新）
  private ingestSession(ss: ServerSession): void {
    this.cacheUser(ss.peer);
    const mapped = mapSession(ss, Api.userId);
    const idx = this.sessions.findIndex((s: ChatSession): boolean => s.id === mapped.id);
    if (idx >= 0) {
      const old = this.sessions[idx];
      old.state = mapped.state;
      old.goodsId = mapped.goodsId;
      old.messages = mapped.messages;
    } else {
      this.sessions.unshift(mapped);
    }
  }

  // ---------------- 数据刷新（供轮询调用） ----------------
  async refreshGoods(): Promise<void> {
    try {
      const rg = await Api.getGoods();
      const goods: GoodsItem[] = [];
      for (const sg of rg.goods) {
        this.cacheUser(sg.seller);
        goods.push(mapGoods(sg));
      }
      this.goods = goods;
      this.offline = false;
    } catch (e) {
    }
  }

  async refreshSession(sid: string): Promise<void> {
    try {
      const rs = await Api.getSession(sid);
      this.ingestSession(rs.session);
      this.offline = false;
    } catch (e) {
    }
  }

  async refreshSessions(): Promise<void> {
    try {
      const rs = await Api.getSessions();
      for (const ss of rs.sessions) {
        this.cacheUser(ss.peer);
        this.ingestSession(ss);
      }
      this.offline = false;
    } catch (e) {
    }
  }

  // ---------------- 路由 ----------------
  go(page: string, param: Object | null = null): void {
    this.nav.pushPathByName(page, param);
  }

  switchTab(index: number): void {
    this.ctrl.changeIndex(index);
  }

  openDetail(goodsId: string): void {
    this.pendingDetailId = goodsId;
    this.go('detail');
  }

  openChat(sessionId: string): void {
    this.pendingChatId = sessionId;
    this.go('chat');
  }

  // ---------------- 认证 ----------------
  async certify(name: string, studentNo: string, college: string): Promise<string> {
    if (name.trim().length < 2) {
      return '请输入真实姓名';
    }
    const sno = studentNo.trim();
    if (!/^\d{8,12}$/.test(sno)) {
      return '学号应为8-12位数字';
    }
    if (college.length === 0) {
      return '请选择所在学院';
    }
    try {
      const body: CertifyBody = { name: name.trim(), studentNo: sno, college: college };
      const resp = await Api.certify(body);
      this.applyUser(resp.user);
      return '';
    } catch (e) {
      return errText(e);
    }
  }

  // ---------------- 发布 ----------------
  async publish(item: GoodsItem): Promise<string> {
    if (!this.me.verified) {
      return '完成学生认证后才能发布';
    }
    const body: PublishBody = {
      kind: item.kind,
      title: item.title,
      desc: item.desc,
      price: item.price,
      course: item.course,
      condition: item.condition,
      errand: item.kind === GoodsKind.Errand ? toServerErrand(item.errand) : null,
      wanted: item.wanted,
      reward: item.reward
    };
    try {
      const rg = await Api.publish(body);
      this.cacheUser(rg.goods.seller);
      this.goods.unshift(mapGoods(rg.goods));
      return '';
    } catch (e) {
      return errText(e);
    }
  }

  // ---------------- 聊天 ----------------
  // 与某用户就某商品开启/进入会话；返回错误信息，空串表示成功
  async openChatWith(peerId: string, goodsId: string, firstText: string): Promise<string> {
    if (this.isBlocked(peerId)) {
      return '你已拉黑该用户，解除后才能再次沟通';
    }
    const body: ChatStartBody = { peerId: peerId, goodsId: goodsId, firstText: firstText };
    try {
      const rs = await Api.createSession(body);
      this.ingestSession(rs.session);
      this.openChat(rs.session.id);
      return '';
    } catch (e) {
      return errText(e);
    }
  }

  async sendMessage(sessionId: string, raw: string): Promise<string> {
    const s = this.findSession(sessionId);
    if (s === undefined) {
      return '会话不存在';
    }
    if (s.state !== SessionState.Active) {
      return '当前会话无法发送消息';
    }
    try {
      const mb: MsgBody = { text: raw };
      await Api.sendMessage(sessionId, mb);
      await this.refreshSession(sessionId);
      return '';
    } catch (e) {
      return errText(e);
    }
  }

  // 演示：模拟对方发来含联系方式的消息（服务端负责打码）
  async demoMessage(sessionId: string): Promise<string> {
    try {
      await Api.demoMessage(sessionId);
      await this.refreshSession(sessionId);
      return '';
    } catch (e) {
      return errText(e);
    }
  }

  // ---------------- 拒聊 / 拉黑 / 举报 ----------------
  async refuseSession(sessionId: string): Promise<string> {
    try {
      const rs = await Api.refuse(sessionId);
      this.ingestSession(rs.session);
      return '';
    } catch (e) {
      return errText(e);
    }
  }

  async resumeSession(sessionId: string): Promise<string> {
    try {
      const rs = await Api.resume(sessionId);
      this.ingestSession(rs.session);
      return '';
    } catch (e) {
      return errText(e);
    }
  }

  async blockPeer(peerId: string): Promise<string> {
    try {
      await Api.block(peerId);
      if (!this.isBlocked(peerId)) {
        this.blacklist.push(peerId);
      }
      // 原地刷新与该用户相关的会话（服务端已追加系统消息并标记 blocked）
      for (const s of this.sessions) {
        if (s.peerId === peerId) {
          await this.refreshSession(s.id);
        }
      }
      return '';
    } catch (e) {
      return errText(e);
    }
  }

  async unblockPeer(peerId: string): Promise<string> {
    try {
      await Api.unblock(peerId);
      this.blacklist = this.blacklist.filter((id: string): boolean => id !== peerId);
      for (const s of this.sessions) {
        if (s.peerId === peerId) {
          await this.refreshSession(s.id);
        }
      }
      return '';
    } catch (e) {
      return errText(e);
    }
  }

  async reportPeer(peerId: string, reason: string): Promise<string> {
    try {
      const body: ReportBody = { targetId: peerId, reason: reason };
      const rr = await Api.report(body);
      const list = mapReports([rr.report]);
      if (list.length > 0) {
        this.reports.unshift(list[0]);
      }
      const u = this.findUser(peerId);
      u.credit = Math.max(0, u.credit - 2);
      return '';
    } catch (e) {
      return errText(e);
    }
  }

  // ---------------- 跑腿公平计价 ----------------
  static sizeExtra(size: string): number {
    switch (size) {
      case 'S':
        return 0;
      case 'M':
        return 1;
      case 'L':
        return 3;
      case 'XL':
        return 5;
      default:
        return 0;
    }
  }

  static weightExtra(weightKg: number): number {
    if (weightKg > 10) {
      return 4;
    }
    if (weightKg > 5) {
      return 2;
    }
    return 0;
  }

  static errandFeeRows(e: ErrandInfo): FeeRow[] {
    const rows: FeeRow[] = [];
    if (e.type === ErrandType.Express) {
      rows.push({ label: `基础跑腿费 ¥2 × ${e.pieces} 份`, amount: FEE_BASE_EXPRESS * e.pieces });
      const extra = AppStore.sizeExtra(e.size);
      if (extra > 0) {
        rows.push({ label: `快递大小(${e.size})加价 ¥${extra} × ${e.pieces}`, amount: extra * e.pieces });
      }
      const w = AppStore.weightExtra(e.weightKg);
      if (w > 0) {
        rows.push({ label: `重量附加(${e.weightKg}kg)`, amount: w });
      }
    } else if (e.type === ErrandType.Takeout) {
      rows.push({ label: `外卖代取 ¥2 × ${e.pieces} 份`, amount: FEE_BASE_TAKEOUT * e.pieces });
    } else {
      rows.push({ label: `食堂代选 ¥3 × ${e.pieces} 份`, amount: FEE_BASE_CANTEEN * e.pieces });
    }
    return rows;
  }

  static feeTotal(rows: FeeRow[]): number {
    let t = 0;
    for (const r of rows) {
      t += r.amount;
    }
    return t;
  }
}

export const store: AppStore = new AppStore();
