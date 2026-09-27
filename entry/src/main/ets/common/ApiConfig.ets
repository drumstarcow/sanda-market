// 服务器地址配置
// 模拟器：10.0.2.2 是模拟器访问宿主机（本机）的回环别名，后端跑在本机 3000 端口
// 真机：请改成电脑在局域网中的 IP（手机与电脑需在同一网络），如 http://192.168.1.8:3000
export class ApiConfig {
  static readonly BASE_URL: string = 'http://10.0.2.2:3000';
}
