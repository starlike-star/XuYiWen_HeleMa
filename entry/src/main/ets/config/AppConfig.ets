// 所有开发环境 API 地址只在此处维护。客户端会依次请求 /api/health，
// 不假设模拟器一定支持任何固定的宿主机映射地址。
export const API_BASE_URL_CANDIDATES: string[] = [
  // 部分模拟器提供该宿主机映射；只作为健康检查候选，不假定一定可用。
  'http://10.0.2.2:3000',
  // VMware NAT（VMnet8）的宿主机地址。
  'http://192.168.128.1:3000',
  // VMware Host-only 与自定义虚拟网卡宿主机地址。
  'http://192.168.10.1:3000',
  'http://172.16.1.1:3000',
  // 当前开发电脑 WLAN 地址，真机或桥接网络可尝试此项。
  'http://172.23.217.223:3000'
];

// 候选均为本机或同一局域网开发服务，缩短单项超时避免错误地址拖慢启动。
export const REQUEST_TIMEOUT_MS: number = 2500;
