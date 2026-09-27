// 个人信息检测与自动打码
// 平台规则：交易与聊天过程中不允许出现个人信息（手机号 / 微信 / QQ / 学号 / 银行卡）
// 发送与发布时自动检测并替换为【已隐藏】，减少私下交易与诈骗风险

export enum SensitiveType {
  Phone = 0,
  WeChat = 1,
  QQ = 2,
  BankCard = 3,
  StudentId = 4
}

export interface SensitiveHit {
  stype: SensitiveType;
  word: string;
}

interface FilterRule {
  stype: SensitiveType;
  re: RegExp;
}

export function sensitiveTypeLabel(t: SensitiveType): string {
  switch (t) {
    case SensitiveType.Phone:
      return '手机号';
    case SensitiveType.WeChat:
      return '微信号';
    case SensitiveType.QQ:
      return 'QQ号';
    case SensitiveType.BankCard:
      return '银行卡号';
    case SensitiveType.StudentId:
      return '学号';
    default:
      return '敏感信息';
  }
}

export class SensitiveFilter {
  private static rules: FilterRule[] = [
    { stype: SensitiveType.Phone, re: /1[3-9]\d[-\s]?\d{4}[-\s]?\d{4}/g },
    { stype: SensitiveType.Phone, re: /1[3-9]\d{9}/g },
    { stype: SensitiveType.WeChat, re: /(微信|weixin|wx|vx|v信)[号:：\s]*[a-zA-Z][-_a-zA-Z0-9]{5,19}/g },
    { stype: SensitiveType.QQ, re: /(qq|扣扣|企鹅)[号:：\s]*[1-9]\d{4,10}/g },
    { stype: SensitiveType.StudentId, re: /(学号|校园卡号)[:：\s]*\d{6,12}/g },
    { stype: SensitiveType.BankCard, re: /\d{16,19}/g }
  ];

  static detect(text: string): SensitiveHit[] {
    const hits: SensitiveHit[] = [];
    for (const r of SensitiveFilter.rules) {
      const m: RegExpMatchArray | null = text.match(r.re);
      if (m !== null) {
        for (const w of m) {
          hits.push({ stype: r.stype, word: w });
        }
      }
    }
    return hits;
  }

  static mask(text: string): string {
    let out: string = text;
    for (const r of SensitiveFilter.rules) {
      out = out.replace(r.re, '【已隐藏】');
    }
    return out;
  }

  static hasSensitive(text: string): boolean {
    return SensitiveFilter.detect(text).length > 0;
  }

  // 生成提示语，如 “手机号、微信号”
  static hintOf(hits: SensitiveHit[]): string {
    const labels: string[] = [];
    for (const h of hits) {
      const label = sensitiveTypeLabel(h.stype);
      if (!labels.includes(label)) {
        labels.push(label);
      }
    }
    return labels.join('、');
  }
}
