// 服务器地址配置：阿里云公网服务器（Ubuntu，systemd 常驻运行）
// 说明：App 统一连云端后端，模拟器/真机/上架包均为同一地址，无需区分环境
// 域名解析生效后可替换为域名形式，如 http://shandamarket.icu:3000
export class ApiConfig {
  static readonly BASE_URL: string = 'http://47.99.129.153:3000';
}
