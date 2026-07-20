# 喝了吗

「喝了吗」是一款 HarmonyOS 每日喝水打卡应用。第一版包含完整开屏动画、今日 8 次喝水进度、液态水杯动画、普通/达标打卡反馈、今日记录和最近 7 天统计，并提供可切换 Mock/MySQL 的独立 REST API。

## 技术栈与结构

- 客户端：HarmonyOS Stage 模型、ArkTS、ArkUI、API 24、Hvigor。
- 服务端：Node.js、Express、mysql2、Luxon。
- 数据库：MySQL 8.x；所有时间按 UTC 保存，服务端以 `Asia/Shanghai` 划分自然日。

主要目录：

```text
entry/src/main/ets/
├─ api/                 # 集中式 HTTP 客户端及 health 地址探测
├─ components/
│  ├─ animations/      # 开屏和液态水杯 Canvas 动画
│  └─ common/          # 标准 ArkUI 状态面板、玻璃底栏
├─ config/             # 唯一 API 地址配置
├─ models/             # API/饮水数据模型
├─ pages/              # 开屏入口、主页面和今日/记录视图
└─ store/              # 加载、打卡、错误与反馈状态

server/
├─ src/
│  ├─ repositories/    # Mock、MySQL、未配置三种数据仓库
│  ├─ app.js           # REST 路由和统一错误响应
│  ├─ waterService.js  # 日期边界、聚合和完成规则
│  └─ server.js        # 服务启动与连接池优雅关闭
├─ sql/init.sql        # 可重复执行的数据库初始化脚本
└─ test/               # 核心 API 测试和 Mock 冒烟测试
```

## 后端启动

需要 Node.js 20 或更高版本。

```powershell
cd server
npm install
Copy-Item .env.example .env
npm start
```

默认 `DATA_MODE=mock`，无需数据库即可体验。Mock 数据只保存在服务进程内，重启后会清空。

可用接口：

- `GET /api/health`
- `GET /api/water/today`
- `POST /api/water/check-in`，可选 JSON：`{"amountMl": 250}`
- `GET /api/water/history?days=7`

成功响应统一为 `{ "success": true, "data": ... }`；错误响应统一为 `{ "success": false, "error": { "code", "message" } }`。客户端 POST 会发送 `Idempotency-Key`，重复请求不会产生重复记录。

## MySQL 配置与初始化

将 `server/.env` 修改为：

```env
DATA_MODE=mysql
SERVER_PORT=3000
APP_TIME_ZONE=Asia/Shanghai
DEFAULT_USER_ID=1
DB_HOST=
DB_PORT=3306
DB_NAME=
DB_USER=
DB_PASSWORD=
```

仓库不会提交 `.env` 或真实凭据。先创建数据库并选中该库，再执行：

```powershell
Get-Content .\sql\init.sql -Raw | mysql -h <host> -P 3306 -u <user> -p <database>
```

初始化脚本使用 `CREATE TABLE IF NOT EXISTS`，默认用户使用固定 ID 和 `ON DUPLICATE KEY UPDATE`，可以重复执行。`water_records` 每次打卡保存一条独立记录；完成率只按每天记录数是否达到 8 判断，`amount_ml` 暂不参与进度。

当 MySQL 环境变量缺失时，服务仍可启动，health 返回 `not_configured`；连接失败返回 `unavailable`。业务接口会返回 `DB_NOT_CONFIGURED` 或 `DB_UNAVAILABLE`，不会暴露数据库连接信息。

## 客户端构建与 API 地址

`entry/src/main/ets/config/AppConfig.ets` 是唯一的 API 地址配置位置。当前候选值为：

1. `http://192.168.128.1:3000`（VMware VMnet8/NAT 宿主机地址）；
2. `http://192.168.10.1:3000`（VMware VMnet1/Host-only 宿主机地址）；
3. `http://172.16.1.1:3000`（当前自定义 VMware 网卡宿主机地址）；
4. `http://172.23.217.223:3000`（本次开发机 WLAN 地址）。

应用启动时逐个请求 `/api/health`，只采用实际成功的地址。这里必须填写宿主机地址，不能填写虚拟机自身地址。网络变化后，应保留虚拟机实际网络模式对应的宿主机地址，避免每项超时造成长时间等待。

`entry/src/main/module.json5` 已声明 `ohos.permission.INTERNET`。本工程 API 24 的清单 schema 实测不接受 `AppScope.app.network`，因此没有保留无效的 `cleartextTraffic` 字段。当前明文 HTTP 已通过开发机请求验证，但由于本次没有连接 HarmonyOS 设备，设备端策略仍需在模拟器/真机上实际验证；如果设备拒绝 HTTP，应优先改用开发 HTTPS 反向代理或按当前 HarmonyOS SDK/设备策略配置受信任域名，不能直接加入无法通过 schema 的字段。

命令行构建：

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon
```

也可以直接在 DevEco Studio 中选择 `entry` 模块运行。项目尚未配置签名，命令行会生成未签名 debug HAP；部署设备时使用 DevEco Studio 自动签名或补充签名配置。

## 本次实际验证结果

验证日期：2026-07-20。

- 后端自动测试：通过；覆盖 health 状态、空记录、饮水量、幂等、第 8 次/超目标、连续 7 天、上海时区跨日、错误响应。
- Mock API 冒烟：通过；health、today、check-in、history 均返回预期数据。
- 开发机 health：`127.0.0.1:3000` 通过，`172.23.217.223:3000` 通过，开发机自身访问 `10.0.2.2:3000` 不可用。
- HarmonyOS debug HAP：通过 API 24 实际构建。
- 模拟器/真机：`hdc list targets` 返回 `[Empty]`，本次无法声称设备端地址、明文 HTTP 或交互已经验证。连接设备后需重新执行下方检查。

设备联调步骤：

1. 启动 Mock API，并确认电脑防火墙允许 TCP 3000。
2. 执行 `hdc list targets`，确认存在设备。
3. 从设备运行应用，观察是否通过 health 进入首页；若首个候选失败，会继续尝试局域网地址。
4. 验证开屏只跳转一次、普通打卡、第 8 次完成动画、记录页和失败重试。
5. 真机需与电脑处于可互访的同一局域网；用浏览器或应用 health 请求确认后再记录为通过。

当前开发机已创建 Windows 防火墙入站规则 `HeLeMaAPI3000`：允许 `LocalSubnet` 访问 TCP 3000，不对互联网任意来源开放。若需要删除该规则，请在管理员 PowerShell 执行 `netsh advfirewall firewall delete rule name=HeLeMaAPI3000`。

VMware 联调时不要把虚拟机自身 IP 写入 `AppConfig.ets`。推荐将虚拟机网卡设为 NAT/DHCP；当前 VMnet8 宿主机地址为 `192.168.128.1`，虚拟机应获得同网段的 `192.168.128.x` 地址，并访问 `http://192.168.128.1:3000/api/health`。手工设置到无宿主机路由的其他网段会导致双向不可达。

## 已完成与暂未完成

已完成：

- 应用名称统一为「喝了吗」，模板 HelloWorld 页面已替换。
- 约 2.5 秒开屏动画及最大 3 秒、只能触发一次的替换式路由兜底。
- 首页采用 Apple Liquid Glass 视觉语义：清晰内容层、折射感工具按钮/主按钮/底栏，以及平面化圆形液体水舱。
- 液体水舱包含双层水面、波纹、气泡、水位平滑上升、普通打卡回弹和第 8 次增强反馈；Canvas 仅绘制水体相关元素。
- 开屏已移除 Emoji，改为独立 Canvas 水滴标志、玻璃承载面、涟漪和单次替换式跳转。
- 第 8 次目标完成状态，超过目标仍可继续打卡。
- 今日时间线、连续最近 7 天统计及空数据/加载/错误/数据库未配置状态。
- Mock/MySQL 数据仓库、UTC 存储、`Asia/Shanghai` 日界线、参数化 SQL、连接池关闭和幂等记录。

第一版暂未实现：

- 撤销或删除打卡（Repository 已保留按记录 ID 删除的扩展边界，但没有公开 API 或 UI）。
- 登录、多用户切换、通知、社交、商城、多设备同步、复杂健康建议和 AI 分析。
- `amountMl` 参与饮水目标计算。
- 复杂粒子效果和复杂统计图表。

已知限制：HarmonyOS/ArkUI 不提供 SwiftUI 的 `glassEffect` 或 `GlassEffectContainer`，当前实现使用标准 ArkUI 组件叠加半透明材质、背景模糊、双层边缘高光、环境色反射和弹性动画复现同等设计语义，并未把页面绘制到 Canvas。Mock 重启后数据清空；真实持久化需要 MySQL；设备联调和明文 HTTP 仍待连接模拟器/真机验证；开发机 IP 变化后需更新集中配置。

建议重点查看开屏水滴与单次跳转、首页液态水位、连续普通打卡反馈、第 8 次完成状态、记录页连续 7 天补零，以及关闭数据库配置后的友好错误页。
