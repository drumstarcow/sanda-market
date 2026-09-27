// 网络层：REST 客户端（基于 @kit.NetworkKit 的 http 模块）
// 鉴权：X-User-Id 头携带当前用户 id（演示用简化方案）
import { http } from '@kit.NetworkKit';
import { ApiConfig } from './ApiConfig';

// ---------------- DTO：与服务端 JSON 结构一致 ----------------
export interface ServerUser {
  id: string;
  nickname: string;
  college: string;
  verified: boolean;
  credit: number;
  studentNoMasked: string;
  hue: string;
}

export interface ServerErrand {
  type: number;
  pieces: number;
  size: string;
  weightKg: number;
  fromPoint: string;
  toPoint: string;
  dishes: string[];
  taste: string;
}

export interface ServerGoods {
  id: string;
  kind: number;
  title: string;
  desc: string;
  price: number;
  course: string;
  condition: number;
  errand: ServerErrand | null;
  sellerId: string;
  timeText: string;
  wanted: boolean;
  reward: number;
  seller: ServerUser | null;
}

export interface ServerMessage {
  id: string;
  fromId: string;
  text: string;
  kind: number;
  timeText: string;
}

export interface ServerSession {
  id: string;
  peerId: string;
  goodsId: string;
  state: string;
  peer: ServerUser | null;
  messages: ServerMessage[];
}

export interface ServerReport {
  id: string;
  fromId: string;
  targetId: string;
  targetName: string;
  reason: string;
  timeText: string;
}

// ---------------- 请求体 ----------------
export interface GuestBody {
  id: string;
}

export interface CertifyBody {
  name: string;
  studentNo: string;
  college: string;
}

export interface PublishBody {
  kind: number;
  title: string;
  desc: string;
  price: number;
  course: string;
  condition: number;
  errand: ServerErrand | null;
  wanted: boolean;
  reward: number;
}

export interface ChatStartBody {
  peerId: string;
  goodsId: string;
  firstText: string;
}

export interface MsgBody {
  text: string;
}

export interface ReportBody {
  targetId: string;
  reason: string;
}

// ---------------- 响应体 ----------------
interface ApiErrorResp {
  error?: string;
}

export interface UserResp {
  user: ServerUser;
}

export interface GoodsResp {
  goods: ServerGoods;
}

export interface GoodsListResp {
  goods: ServerGoods[];
}

export interface SessionResp {
  session: ServerSession;
}

export interface SessionListResp {
  sessions: ServerSession[];
}

export interface BlacklistResp {
  blacklist: ServerUser[];
}

export interface ReportResp {
  report: ServerReport;
}

export interface ReportListResp {
  reports: ServerReport[];
}

export interface OkResp {
  ok: boolean;
}

// ---------------- Api ----------------
export class Api {
  static userId: string = '';

  private static async raw(path: string, method: http.RequestMethod, bodyText: string): Promise<string> {
    const hr = http.createHttp();
    try {
      const header: Record<string, string> = { 'Content-Type': 'application/json' };
      if (Api.userId.length > 0) {
        header['x-user-id'] = Api.userId;
      }
      const opts: http.HttpRequestOptions = {
        method: method,
        header: header,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 8000
      };
      if (bodyText.length > 0) {
        opts.extraData = bodyText;
      }
      const resp = await hr.request(`${ApiConfig.BASE_URL}${path}`, opts);
      const text = resp.result as string;
      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        return text;
      }
      let msg = `请求失败(${resp.responseCode})`;
      try {
        const errObj = JSON.parse(text) as ApiErrorResp;
        if (errObj.error !== undefined && errObj.error.length > 0) {
          msg = errObj.error;
        }
      } catch (ignored) {
      }
      throw new Error(msg);
    } finally {
      hr.destroy();
    }
  }

  private static async get<T>(path: string): Promise<T> {
    const text = await Api.raw(path, http.RequestMethod.GET, '');
    return JSON.parse(text) as T;
  }

  private static async post<B, T>(path: string, body: B): Promise<T> {
    const text = await Api.raw(path, http.RequestMethod.POST, JSON.stringify(body));
    return JSON.parse(text) as T;
  }

  private static async postEmpty<T>(path: string): Promise<T> {
    const text = await Api.raw(path, http.RequestMethod.POST, '');
    return JSON.parse(text) as T;
  }

  static async guest(savedId: string): Promise<UserResp> {
    const body: GuestBody = { id: savedId };
    return Api.post<GuestBody, UserResp>('/api/auth/guest', body);
  }

  static async certify(body: CertifyBody): Promise<UserResp> {
    return Api.post<CertifyBody, UserResp>('/api/auth/certify', body);
  }

  static async getGoods(): Promise<GoodsListResp> {
    return Api.get<GoodsListResp>('/api/goods');
  }

  static async publish(body: PublishBody): Promise<GoodsResp> {
    return Api.post<PublishBody, GoodsResp>('/api/goods', body);
  }

  static async getSessions(): Promise<SessionListResp> {
    return Api.get<SessionListResp>('/api/sessions');
  }

  static async createSession(body: ChatStartBody): Promise<SessionResp> {
    return Api.post<ChatStartBody, SessionResp>('/api/sessions', body);
  }

  static async getSession(id: string): Promise<SessionResp> {
    return Api.get<SessionResp>(`/api/sessions/${id}`);
  }

  static async sendMessage(id: string, body: MsgBody): Promise<OkResp> {
    return Api.post<MsgBody, OkResp>(`/api/sessions/${id}/messages`, body);
  }

  static async demoMessage(id: string): Promise<OkResp> {
    return Api.postEmpty<OkResp>(`/api/sessions/${id}/demo`);
  }

  static async refuse(id: string): Promise<SessionResp> {
    return Api.postEmpty<SessionResp>(`/api/sessions/${id}/refuse`);
  }

  static async resume(id: string): Promise<SessionResp> {
    return Api.postEmpty<SessionResp>(`/api/sessions/${id}/resume`);
  }

  static async block(id: string): Promise<OkResp> {
    return Api.postEmpty<OkResp>(`/api/users/${id}/block`);
  }

  static async unblock(id: string): Promise<OkResp> {
    return Api.postEmpty<OkResp>(`/api/users/${id}/unblock`);
  }

  static async getBlacklist(): Promise<BlacklistResp> {
    return Api.get<BlacklistResp>('/api/blacklist');
  }

  static async getReports(): Promise<ReportListResp> {
    return Api.get<ReportListResp>('/api/reports');
  }

  static async report(body: ReportBody): Promise<ReportResp> {
    return Api.post<ReportBody, ReportResp>('/api/reports', body);
  }
}
