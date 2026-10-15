// 服务器地址配置：阿里云公网服务器（Ubuntu，systemd 常驻运行）
// 说明：App 统一连云端后端，模拟器/真机/上架包均为同一地址，无需区分环境
// 备案已完成，域名访问正常（与工信部备案信息一致）
export class ApiConfig {
  static readonly BASE_URL: string = 'http://shandamarket.icu:3000';
}
