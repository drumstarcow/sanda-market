// 杉集后端服务（零依赖，Node 内置模块）
// 启动：node server.js   （默认 0.0.0.0:3000，手机与电脑同一局域网即可访问）
// 说明：JSON 文件存储；认证为简化版（X-User-Id 头），生产环境应替换为登录态/Token

const http = require('http');
const https = require('https');
const crypto = require('crypto');
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

// ---------------- 短信验证码（实名核验） ----------------
// SMS_PROVIDER: mock=开发调试（响应带 devCode）；aliyun=生产（接入阿里云短信，签名"杉集"）
const SMS_PROVIDER = process.env.SMS_PROVIDER || 'mock';
const SMS_TTL = 5 * 60 * 1000;        // 验证码有效期 5 分钟
const SMS_GAP = 60 * 1000;            // 同一号码两次发码最小间隔
const SMS_DAY_LIMIT = 10;             // 同一号码每日上限
const IP_HOUR_LIMIT = 20;             // 同一 IP 每小时上限
const smsCodes = new Map();           // phone -> {code, exp}
const smsSendLog = new Map();         // phone -> [ts]
const ipSendLog = new Map();          // ip -> [ts]

function pruneTs(list, windowMs) {
  const now = Date.now();
  return list.filter((t) => now - t < windowMs);
}

function sendSmsCode(phone, code) {
  // 生产模式：接入阿里云短信后在此调用 SDK 发送（签名"杉集"、验证码模板）
  // mock 模式：仅打印日志，验证码随接口响应返回用于调试
  console.log(`[sms] mock send to ${phone}: code=${code}`);
  return true;
}

// ---------------- 运营商本机号码校验（阿里云号码认证服务 PNVS） ----------------
// 凭据通过环境变量注入（不入库不进 git）：PNVS_AK_ID / PNVS_AK_SECRET
// SMS_PROVIDER=pnvs 时 App 端使用运营商本机校验；mock 时走验证码路径（模拟器调试）
const PNVS_AK_ID = process.env.PNVS_AK_ID || '';
const PNVS_AK_SECRET = process.env.PNVS_AK_SECRET || '';

function pctEnc(s) {
  return encodeURIComponent(String(s)).replace(/\+/g, '%20').replace(/\*/g, '%2A').replace(/%7E/g, '~');
}

function httpsPostQuery(url, cb, timeoutMs) {
  const u = new URL(url);
  const req = https.request({
    hostname: u.hostname,
    path: u.pathname + u.search,
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': 0 }
  }, (r) => {
    let raw = '';
    r.on('data', (d) => { raw += d; });
    r.on('end', () => {
      try { cb(null, JSON.parse(raw)); } catch (e) { cb(e); }
    });
  });
  req.setTimeout(timeoutMs || 6000, () => req.destroy(new Error('timeout')));
  req.on('error', (e) => cb(e));
  req.end();
}

// 调阿里云 Dypnsapi.VerifyMobile：核验 token 对应的本机号与 phone 是否一致
function pnvsVerify(phone, token) {
  return new Promise((resolve) => {
    if (!PNVS_AK_ID || !PNVS_AK_SECRET) {
      return resolve({ ok: false, error: '服务端未配置号码认证凭据' });
    }
    const params = {
      AccessKeyId: PNVS_AK_ID,
      AccessCode: token,
      Action: 'VerifyMobile',
      Format: 'JSON',
      PhoneNumber: phone,
      RegionId: 'cn-hangzhou',
      SignatureMethod: 'HMAC-SHA1',
      SignatureNonce: crypto.randomUUID(),
      SignatureVersion: '1.0',
      Timestamp: new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'),
      Version: '2017-05-25'
    };
    const keys = Object.keys(params).sort();
    const qs = keys.map((k) => pctEnc(k) + '=' + pctEnc(params[k])).join('&');
    const sts = 'POST&%2F&' + pctEnc(qs);
    const sig = crypto.createHmac('sha1', PNVS_AK_SECRET + '&').update(sts).digest('base64');
    const url = 'https://dypnsapi.aliyuncs.com/?Signature=' + pctEnc(sig) + '&' + qs;
    httpsPostQuery(url, (err, data) => {
      if (err || !data) {
        return resolve({ ok: false, error: '号码校验服务异常，请稍后再试' });
      }
      if (data.Code === 'OK') {
        const vr = data.GateVerifyResultDTO && data.GateVerifyResultDTO.VerifyResult;
        return resolve({ ok: vr === 'PASS' });
      }
      resolve({ ok: false, error: '号码校验未通过（' + String(data.Code) + '）' });
    }, 6000);
  });
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
      { id: 'u1', nickname: '小王同学', college: '信息科学与技术学院', verified: true, credit: 96, studentNoMasked: '23****17', phoneMasked: '138****5678', hue: '#3172F0' },
      { id: 'u2', nickname: '干饭小张', college: '商学院', verified: true, credit: 92, studentNoMasked: '24****53', phoneMasked: '159****2211', hue: '#B7791F' },
      { id: 'u3', nickname: '跑腿老王', college: '教育学院', verified: true, credit: 94, studentNoMasked: '22****08', phoneMasked: '187****3344', hue: '#0A9F58' },
      { id: 'u4', nickname: '学长阿凯', college: '艺术设计学院', verified: true, credit: 88, studentNoMasked: '21****66', phoneMasked: '135****7788', hue: '#D94838' }
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
  return { id: u.id, nickname: u.nickname, college: u.college, verified: u.verified, credit: u.credit, studentNoMasked: u.studentNoMasked, phoneMasked: u.phoneMasked || '', hue: u.hue };
}

function goodsView(g) {
  const seller = db.users.find((u) => u.id === g.sellerId);
  return { ...g, seller: seller ? userView(seller) : null };
}

// 实名判定：学生认证 + 手机号验证码核验均完成后，才允许发布/私聊等 UGC 行为
function isRealnamed(u) {
  return !!(u && u.verified && (u.phoneMasked || '').length > 0);
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
        return send(res, 200, { user: userView(exist), authMode: SMS_PROVIDER });
      }
    }
    const u = { id: nextId('u'), nickname: '匿名同学', college: '', verified: false, credit: 90, studentNoMasked: '', phoneMasked: '', hue: '#0A9F58' };
    db.users.push(u);
    saveDb();
    return send(res, 200, { user: userView(u), authMode: SMS_PROVIDER });
  }

  // 发送短信验证码（实名核验第一步，服务端强制防刷）
  if (p === '/api/auth/sms-code' && method === 'POST') {
    const phone = String(body.phone || '').trim();
    if (!/^1[3-9]\d{9}$/.test(phone)) {
      return send(res, 400, { error: '请输入正确的11位手机号' });
    }
    const ip = req.socket.remoteAddress || 'unknown';
    const now = Date.now();
    // 防刷1：同一号码 60 秒内仅一条
    const plist = pruneTs(smsSendLog.get(phone) || [], 24 * 3600 * 1000);
    if (plist.length > 0 && now - plist[plist.length - 1] < SMS_GAP) {
      return send(res, 429, { error: '发送太频繁，请60秒后再试' });
    }
    // 防刷2：同一号码每日上限
    if (plist.length >= SMS_DAY_LIMIT) {
      return send(res, 429, { error: '今日验证码发送已达上限，请明天再试' });
    }
    // 防刷3：同一 IP 每小时上限
    const ilist = pruneTs(ipSendLog.get(ip) || [], 3600 * 1000);
    if (ilist.length >= IP_HOUR_LIMIT) {
      return send(res, 429, { error: '操作过于频繁，请稍后再试' });
    }
    const code = String(Math.floor(100000 + Math.random() * 900000));
    smsCodes.set(phone, { code: code, exp: now + SMS_TTL });
    plist.push(now);
    smsSendLog.set(phone, plist);
    ilist.push(now);
    ipSendLog.set(ip, ilist);
    sendSmsCode(phone, code);
    const resp = { ok: true };
    if (SMS_PROVIDER === 'mock') {
      resp.devCode = code; // 仅调试模式返回，生产切换 aliyun 后不再下发
    }
    return send(res, 200, resp);
  }

  // 学生认证（实名核验：pnvs=运营商本机号码校验；mock=短信验证码调试）
  if (p === '/api/auth/certify' && method === 'POST') {
    if (!me) {
      return send(res, 401, { error: '请先获取身份' });
    }
    const name = String(body.name || '').trim();
    const sno = String(body.studentNo || '').trim();
    const college = String(body.college || '').trim();
    const phone = String(body.phone || '').trim();
    const pnvsToken = String(body.pnvsToken || '').trim();
    const smsCode = String(body.smsCode || '').trim();
    if (!/^1[3-9]\d{9}$/.test(phone)) {
      return send(res, 400, { error: '请输入正确的11位手机号' });
    }
    if (pnvsToken.length > 0) {
      // 运营商本机号码校验路径（生产/真机）：服务端向阿里云核验 token 与手机号一致性
      const ipC = req.socket.remoteAddress || 'unknown';
      const ilistC = pruneTs(ipSendLog.get(ipC) || [], 3600 * 1000);
      if (ilistC.length >= IP_HOUR_LIMIT) {
        return send(res, 429, { error: '操作过于频繁，请稍后再试' });
      }
      ilistC.push(Date.now());
      ipSendLog.set(ipC, ilistC);
      const vr = await pnvsVerify(phone, pnvsToken);
      if (!vr.ok) {
        return send(res, 400, { error: vr.error || '本机号码校验未通过' });
      }
    } else if (SMS_PROVIDER === 'pnvs') {
      return send(res, 400, { error: '请完成本机号码校验后再提交认证' });
    } else {
      // 短信验证码路径（mock 调试）
      const entry = smsCodes.get(phone);
      if (!entry || entry.exp < Date.now()) {
        return send(res, 400, { error: '验证码已过期，请重新获取' });
      }
      if (entry.code !== smsCode) {
        return send(res, 400, { error: '验证码不正确' });
      }
      smsCodes.delete(phone); // 验证码一次性使用
    }
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
    me.phoneMasked = `${phone.substring(0, 3)}****${phone.substring(7)}`;
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
    if (!isRealnamed(me)) {
      return send(res, 403, { error: '完成学生认证（含手机号验证）后才能发布' });
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
    if (!isRealnamed(me)) {
      return send(res, 403, { error: '完成学生认证（含手机号验证）后才能私聊' });
    }
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

  const mSess = p.match(/^\/api\/sessions\/([^/]+)(\/messages|\/refuse|\/resume)?$/);
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
      if (!isRealnamed(me)) {
        return send(res, 403, { error: '完成学生认证（含手机号验证）后才能发送消息' });
      }
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
  console.log(`杉集后端已启动: http://0.0.0.0:${PORT}  (数据文件: ${DB_FILE})`);
});
