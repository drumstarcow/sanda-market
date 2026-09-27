// 杉达集市后端服务（零依赖，Node 内置模块）
// 启动：node server.js   （默认 0.0.0.0:3000，手机与电脑同一局域网即可访问）
// 说明：演示用 JSON 文件存储；认证为简化版（X-User-Id 头），生产环境应替换为登录态/Token

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3000;
const DB_FILE = path.join(__dirname, 'data', 'db.json');

// ---------------- 敏感信息过滤（与鸿蒙端规则一致） ----------------
const MASK = '【已隐藏】';
const RULES = [
  /1[3-9]\d[-\s]?\d{4}[-\s]?\d{4}/g,
  /1[3-9]\d{9}/g,
  /(微信|weixin|wx|vx|v信)[号:：\s]*[a-zA-Z][-_a-zA-Z0-9]{5,19}/g,
  /(qq|扣扣|企鹅)[号:：\s]*[1-9]\d{4,10}/g,
  /(学号|校园卡号)[:：\s]*\d{6,12}/g,
  /\d{16,19}/g
];
const LABELS = [
  { re: /1[3-9]\d[-\s]?\d{4}[-\s]?\d{4}|1[3-9]\d{9}/, label: '手机号' },
  { re: /微信|weixin|wx|vx|v信/i, label: '微信号' },
  { re: /qq|扣扣|企鹅/i, label: 'QQ号' },
  { re: /学号|校园卡号/, label: '学号' },
  { re: /\d{16,19}/, label: '银行卡号' }
];

function detectHits(text) {
  const hits = [];
  for (const re of RULES) {
    const m = text.match(re);
    if (m) {
      hits.push(...m);
    }
  }
  return hits;
}

function maskText(text) {
  let out = text;
  for (const re of RULES) {
    out = out.replace(re, MASK);
  }
  return out;
}

function hintOf(text) {
  const labels = [];
  for (const it of LABELS) {
    if (it.re.test(text) && !labels.includes(it.label)) {
      labels.push(it.label);
    }
  }
  return labels.join('、');
}

// ---------------- 存储 ----------------
let db = null;

function seedDb() {
  const now = new Date();
  const t = (d) => {
    const x = new Date(now.getTime() - d * 3600 * 1000);
    return `${x.getMonth() + 1}/${x.getDate()} ${x.getHours()}:${String(x.getMinutes()).padStart(2, '0')}`;
  };
  return {
    users: [
      { id: 'u1', nickname: '杉达小王', college: '信息科学与技术学院', verified: true, credit: 96, studentNoMasked: '23****17', hue: '#3172F0' },
      { id: 'u2', nickname: '干饭小张', college: '商学院', verified: true, credit: 92, studentNoMasked: '24****53', hue: '#B7791F' },
      { id: 'u3', nickname: '跑腿老王', college: '教育学院', verified: true, credit: 94, studentNoMasked: '22****08', hue: '#0A9F58' },
      { id: 'u4', nickname: '学长阿凯', college: '艺术设计学院', verified: true, credit: 88, studentNoMasked: '21****66', hue: '#D94838' }
    ],
    goods: [
      { id: 'g1', kind: 0, title: '高等数学(上)·同济第七版', desc: '大一上学期用书，无笔记无划线，附赠课后习题答案打印版。', price: 12, course: '高等数学', condition: 1, errand: null, sellerId: 'u1', timeText: t(3), wanted: false, reward: 0 },
      { id: 'g2', kind: 0, title: '数据结构(C语言版)', desc: '期末考完出，书内有少量铅笔标记可擦除。', price: 18, course: '数据结构', condition: 2, errand: null, sellerId: 'u4', timeText: t(15), wanted: false, reward: 0 },
      { id: 'g3', kind: 0, title: '求购：线性代数教材(任何版本)', desc: '下学期要用，八九成新即可，校内面交。', price: 15, course: '线性代数', condition: 2, errand: null, sellerId: 'u2', timeText: t(5), wanted: true, reward: 0 },
      { id: 'g4', kind: 1, title: '快递代拿 | 驿站→西区宿舍', desc: '两个包裹一起拿，一个鞋盒大小一个中箱。', price: 6, course: '', condition: 2, sellerId: 'u3', timeText: t(2), wanted: false, reward: 0,
        errand: { type: 0, pieces: 2, size: 'M', weightKg: 3.5, fromPoint: '菜鸟驿站(学生服务中心B1)', toPoint: '西区6号楼', dishes: [], taste: '' } },
      { id: 'g5', kind: 1, title: '外卖跑腿 | 北门→教学楼', desc: '中午12点的外卖，帮忙带到三H楼下即可。', price: 2.5, course: '', condition: 2, sellerId: 'u3', timeText: t(1), wanted: false, reward: 0,
        errand: { type: 1, pieces: 1, size: 'M', weightKg: 1, fromPoint: '北门外卖架', toPoint: '教学楼三H', dishes: [], taste: '' } },
      { id: 'g6', kind: 1, title: '食堂代选 | 二食堂麻辣香锅', desc: '帮忙选菜打饭，15:00前送到西区3号楼。', price: 3, course: '', condition: 2, sellerId: 'u2', timeText: t(1), wanted: false, reward: 0,
        errand: { type: 2, pieces: 1, size: 'M', weightKg: 0, fromPoint: '二食堂2F·麻辣香锅窗口', toPoint: '西区3号楼', dishes: ['麻辣香锅'], taste: '微辣·不要香菜·少油' } },
      { id: 'g7', kind: 2, title: '求助：谁会装Python环境？', desc: '电脑是新买的，装Python总报错，希望有同学远程或线下指导一下，必有感谢。', price: 0, course: '', condition: 2, errand: null, sellerId: 'u4', timeText: t(1), wanted: false, reward: 5 },
      { id: 'g8', kind: 2, title: '失物招领：拾到校园卡一张', desc: '昨天在二食堂二楼捡到一张校园卡，失主可到信息学院办公室领取（已交给辅导员）。', price: 0, course: '', condition: 2, errand: null, sellerId: 'u1', timeText: t(16), wanted: false, reward: 0 }
    ],
    sessions: [],
    reports: [],
    blacklist: [],
    seq: 100
  };
}

function loadDb() {
  try {
    db = JSON.parse(fs.readFileSync(DB_FILE, 'utf-8'));
  } catch (e) {
    db = seedDb();
    saveDb();
  }
}

function saveDb() {
  fs.mkdirSync(path.dirname(DB_FILE), { recursive: true });
  fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2));
}

function nextId(prefix) {
  db.seq += 1;
  return `${prefix}${db.seq}`;
}

function nowText() {
  const d = new Date();
  return `${d.getMonth() + 1}/${d.getDate()} ${d.getHours()}:${String(d.getMinutes()).padStart(2, '0')}`;
}

// ---------------- 会话状态（按参与者计算视图） ----------------
function findSession(id) {
  return db.sessions.find((s) => s.id === id);
}

function peerIdOf(session, userId) {
  return session.aId === userId ? session.bId : session.aId;
}

// 返回该用户视角的状态字符串
function stateFor(session, userId) {
  const other = peerIdOf(session, userId);
  if (session.blocked.includes(userId)) {
    return 'blockedByMe';
  }
  if (session.blocked.includes(other)) {
    return 'blockedByPeer';
  }
  if (session.refused.includes(userId)) {
    return 'refusedByMe';
  }
  if (session.refused.includes(other)) {
    return 'refusedByPeer';
  }
  return 'active';
}

function closed(session) {
  return session.blocked.length > 0 || session.refused.length > 0;
}

function sessionView(s, userId) {
  const peer = db.users.find((u) => u.id === peerIdOf(s, userId));
  return {
    id: s.id,
    peerId: peerIdOf(s, userId),
    goodsId: s.goodsId,
    state: stateFor(s, userId),
    peer: peer ? userView(peer) : null,
    messages: s.messages
  };
}

function appendMsg(s, fromId, text, kind) {
  const m = { id: nextId('m'), fromId, text, kind, timeText: nowText() };
  s.messages.push(m);
  return m;
}

// ---------------- 工具 ----------------
function send(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve) => {
    let data = '';
    req.on('data', (c) => {
      data += c;
    });
    req.on('end', () => {
      try {
        resolve(data ? JSON.parse(data) : {});
      } catch (e) {
        resolve({});
      }
    });
  });
}

function currentUser(req) {
  const id = req.headers['x-user-id'];
  if (!id) {
    return null;
  }
  return db.users.find((u) => u.id === id) || null;
}

function userView(u) {
  return { id: u.id, nickname: u.nickname, college: u.college, verified: u.verified, credit: u.credit, studentNoMasked: u.studentNoMasked, hue: u.hue };
}

function goodsView(g) {
  const seller = db.users.find((u) => u.id === g.sellerId);
  return { ...g, seller: seller ? userView(seller) : null };
}

// ---------------- 路由 ----------------
async function handle(req, res) {
  const url = new URL(req.url, 'http://localhost');
  const p = url.pathname;
  const method = req.method;
  const body = await readBody(req);
  const me = currentUser(req);

  // 健康检查
  if (p === '/api/health' && method === 'GET') {
    return send(res, 200, { ok: true });
  }

  // 访客注册/找回（body.id 为本机保存的用户 id，可缺省）
  if (p === '/api/auth/guest' && method === 'POST') {
    if (body.id) {
      const exist = db.users.find((u) => u.id === body.id);
      if (exist) {
        return send(res, 200, { user: userView(exist) });
      }
    }
    const u = { id: nextId('u'), nickname: '杉达同学', college: '', verified: false, credit: 90, studentNoMasked: '', hue: '#0A9F58' };
    db.users.push(u);
    saveDb();
    return send(res, 200, { user: userView(u) });
  }

  // 学生认证
  if (p === '/api/auth/certify' && method === 'POST') {
    if (!me) {
      return send(res, 401, { error: '请先获取身份' });
    }
    const name = String(body.name || '').trim();
    const sno = String(body.studentNo || '').trim();
    const college = String(body.college || '').trim();
    if (name.length < 2) {
      return send(res, 400, { error: '请输入真实姓名' });
    }
    if (!/^\d{8,12}$/.test(sno)) {
      return send(res, 400, { error: '学号应为8-12位数字' });
    }
    if (!college) {
      return send(res, 400, { error: '请选择所在学院' });
    }
    me.verified = true;
    me.college = college;
    me.studentNoMasked = `${sno.substring(0, 2)}****${sno.substring(sno.length - 2)}`;
    me.credit = Math.min(100, me.credit + 2);
    saveDb();
    return send(res, 200, { user: userView(me) });
  }

  if (!me) {
    return send(res, 401, { error: '未登录' });
  }

  // 用户
  const mUser = p.match(/^\/api\/users\/([^/]+)(\/block|\/unblock)?$/);
  if (mUser) {
    const target = db.users.find((u) => u.id === mUser[1]);
    if (!target) {
      return send(res, 404, { error: '用户不存在' });
    }
    if (method === 'GET') {
      return send(res, 200, { user: userView(target) });
    }
    if (method === 'POST' && mUser[2] === '/block') {
      if (!db.blacklist.find((b) => b.ownerId === me.id && b.peerId === target.id)) {
        db.blacklist.push({ ownerId: me.id, peerId: target.id });
      }
      for (const s of db.sessions) {
        const isPair = (s.aId === me.id && s.bId === target.id) || (s.aId === target.id && s.bId === me.id);
        if (isPair && !s.blocked.includes(me.id)) {
          s.blocked.push(me.id);
          appendMsg(s, 'system', '你已拉黑对方，双方消息均不再送达。', 2);
        }
      }
      saveDb();
      return send(res, 200, { ok: true });
    }
    if (method === 'POST' && mUser[2] === '/unblock') {
      db.blacklist = db.blacklist.filter((b) => !(b.ownerId === me.id && b.peerId === target.id));
      for (const s of db.sessions) {
        const isPair = (s.aId === me.id && s.bId === target.id) || (s.aId === target.id && s.bId === me.id);
        if (isPair && s.blocked.includes(me.id)) {
          s.blocked = s.blocked.filter((x) => x !== me.id);
        }
      }
      saveDb();
      return send(res, 200, { ok: true });
    }
  }

  // 黑名单列表（返回被拉黑用户的视图，便于客户端展示）
  if (p === '/api/blacklist' && method === 'GET') {
    const users = db.blacklist
      .filter((b) => b.ownerId === me.id)
      .map((b) => db.users.find((u) => u.id === b.peerId))
      .filter((u) => !!u)
      .map((u) => userView(u));
    return send(res, 200, { blacklist: users });
  }

  // 商品
  if (p === '/api/goods' && method === 'GET') {
    const kw = (url.searchParams.get('kw') || '').trim();
    const kind = url.searchParams.get('kind');
    let list = db.goods.slice().reverse();
    if (kind !== null && kind !== '' && kind !== undefined) {
      list = list.filter((g) => String(g.kind) === kind);
    }
    if (kw) {
      list = list.filter((g) => g.title.includes(kw) || g.desc.includes(kw) || (g.course || '').includes(kw));
    }
    return send(res, 200, { goods: list.map(goodsView) });
  }

  if (p === '/api/goods' && method === 'POST') {
    if (!me.verified) {
      return send(res, 403, { error: '完成学生认证后才能发布' });
    }
    const g = {
      id: nextId('g'),
      kind: Number(body.kind) || 0,
      title: maskText(String(body.title || '').trim()),
      desc: maskText(String(body.desc || '').trim()),
      price: Number(body.price) || 0,
      course: String(body.course || ''),
      condition: Number(body.condition) || 2,
      errand: body.errand || null,
      sellerId: me.id,
      timeText: nowText(),
      wanted: !!body.wanted,
      reward: Number(body.reward) || 0
    };
    if (!g.title) {
      return send(res, 400, { error: '标题不能为空' });
    }
    db.goods.push(g);
    saveDb();
    return send(res, 200, { goods: goodsView(g) });
  }

  const mGoods = p.match(/^\/api\/goods\/([^/]+)$/);
  if (mGoods && method === 'GET') {
    const g = db.goods.find((x) => x.id === mGoods[1]);
    if (!g) {
      return send(res, 404, { error: '内容不存在' });
    }
    return send(res, 200, { goods: goodsView(g) });
  }

  // 会话
  if (p === '/api/sessions' && method === 'GET') {
    const list = db.sessions
      .filter((s) => s.aId === me.id || s.bId === me.id)
      .map((s) => sessionView(s, me.id));
    return send(res, 200, { sessions: list });
  }

  if (p === '/api/sessions' && method === 'POST') {
    const peer = db.users.find((u) => u.id === body.peerId);
    if (!peer) {
      return send(res, 404, { error: '对方不存在' });
    }
    if (db.blacklist.find((b) => b.ownerId === me.id && b.peerId === peer.id)) {
      return send(res, 409, { error: '你已拉黑该用户，解除后才能再次沟通' });
    }
    let s = db.sessions.find((x) => (x.aId === me.id && x.bId === peer.id) || (x.aId === peer.id && x.bId === me.id));
    if (!s) {
      s = { id: nextId('s'), aId: me.id, bId: peer.id, goodsId: String(body.goodsId || ''), refused: [], blocked: [], messages: [] };
      db.sessions.push(s);
    }
    if (body.firstText) {
      const hits = detectHits(String(body.firstText));
      appendMsg(s, me.id, maskText(String(body.firstText)), hits.length > 0 ? 1 : 0);
      if (hits.length > 0) {
        appendMsg(s, 'system', `你消息中的联系方式（${hintOf(String(body.firstText))}）已自动隐藏。为保护隐私与交易安全，请保持站内沟通。`, 2);
      }
    }
    saveDb();
    return send(res, 200, { session: sessionView(s, me.id) });
  }

  const mSess = p.match(/^\/api\/sessions\/([^/]+)(\/messages|\/refuse|\/resume|\/demo)?$/);
  if (mSess) {
    const s = findSession(mSess[1]);
    if (!s || (s.aId !== me.id && s.bId !== me.id)) {
      return send(res, 404, { error: '会话不存在' });
    }
    const action = mSess[2] || '';

    if (method === 'GET' && action === '') {
      return send(res, 200, { session: sessionView(s, me.id) });
    }

    if (method === 'POST' && action === '/messages') {
      if (closed(s)) {
        return send(res, 409, { error: '当前会话无法发送消息' });
      }
      const raw = String(body.text || '').trim();
      if (!raw) {
        return send(res, 400, { error: '消息不能为空' });
      }
      const hits = detectHits(raw);
      const msg = appendMsg(s, me.id, maskText(raw), hits.length > 0 ? 1 : 0);
      const tips = [];
      if (hits.length > 0) {
        const tip = appendMsg(s, 'system', `你消息中的联系方式（${hintOf(raw)}）已自动隐藏。为保护隐私与交易安全，请保持站内沟通。`, 2);
        tips.push(tip);
      }
      saveDb();
      return send(res, 200, { messages: [msg, ...tips] });
    }

    if (method === 'POST' && action === '/demo') {
      if (closed(s)) {
        return send(res, 409, { error: '当前会话无法接收消息' });
      }
      const raw = '我是校外代购，加我微信 sanda_shop99 或打 13812345678 付款更快～';
      const msg = appendMsg(s, peerIdOf(s, me.id), maskText(raw), 1);
      const tip = appendMsg(s, 'system', `对方消息中的联系方式（${hintOf(raw)}）已自动隐藏。警惕校外人员私下转账要求，谨防诈骗。`, 2);
      saveDb();
      return send(res, 200, { messages: [msg, tip] });
    }

    if (method === 'POST' && action === '/refuse') {
      if (!s.refused.includes(me.id)) {
        s.refused.push(me.id);
        appendMsg(s, 'system', '你已单方面拒绝此会话，对方的新消息将不再送达。', 2);
      }
      saveDb();
      return send(res, 200, { session: sessionView(s, me.id) });
    }

    if (method === 'POST' && action === '/resume') {
      if (s.refused.includes(me.id)) {
        s.refused = s.refused.filter((x) => x !== me.id);
        appendMsg(s, 'system', '你已恢复接收该会话的消息。', 2);
      }
      saveDb();
      return send(res, 200, { session: sessionView(s, me.id) });
    }
  }

  // 举报
  if (p === '/api/reports' && method === 'GET') {
    return send(res, 200, { reports: db.reports.filter((r) => r.fromId === me.id) });
  }

  if (p === '/api/reports' && method === 'POST') {
    const target = db.users.find((u) => u.id === body.targetId);
    if (!target) {
      return send(res, 404, { error: '用户不存在' });
    }
    const r = { id: nextId('r'), fromId: me.id, targetId: target.id, targetName: target.nickname, reason: String(body.reason || '涉嫌违规'), timeText: nowText() };
    db.reports.push(r);
    target.credit = Math.max(0, target.credit - 2);
    saveDb();
    return send(res, 200, { report: r });
  }

  return send(res, 404, { error: 'not found' });
}

loadDb();
http.createServer((req, res) => {
  handle(req, res).catch((e) => {
    send(res, 500, { error: String(e) });
  });
}).listen(PORT, '0.0.0.0', () => {
  console.log(`杉达集市后端已启动: http://0.0.0.0:${PORT}  (数据文件: ${DB_FILE})`);
});
