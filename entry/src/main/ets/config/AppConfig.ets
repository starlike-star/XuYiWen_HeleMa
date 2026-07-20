// 所有开发环境 API 地址只在此处维护。客户端会按顺序请求 /api/health，
// 不会假定模拟器必然支持某一个宿主机映射地址。
export const API_BASE_URL_CANDIDATES: string[] = [
  // VMware NAT（VMnet8）的宿主机地址，虚拟机通常应优先访问这一项。
  'http://192.168.128.1:3000',
  // VMware Host-only / 自定义虚拟网卡的宿主机地址。
  'http://192.168.10.1:3000',
  'http://172.16.1.1:3000',
  // 电脑当前 WLAN 地址，桥接网络或同一局域网真机可尝试这一项。
  'http://172.23.217.223:3000'
];

export const REQUEST_TIMEOUT_MS: number = 5000;
export const WATER_TARGET: number = 8;
