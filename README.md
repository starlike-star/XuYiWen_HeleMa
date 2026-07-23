# 喝了吗

应用正式包名为 `com.helema.water`，不再使用模板包名 `com.example.myapplication`。唯一包名可避免开发环境中代理提醒配额与其他模板应用或旧调试安装发生冲突。

「喝了吗」是一款 HarmonyOS 每日喝水打卡应用。当前版本提供动态目标、单次饮水量、撤销与删除、周/月统计、月历、连续达标和本地滚动提醒，并支持 Mock 与 MySQL 两种数据模式。

## 技术栈与目录

- 客户端：HarmonyOS Stage、ArkTS、ArkUI、API 24、Hvigor。
- 服务端：Node.js、Express、mysql2、Luxon。
- 数据库：MySQL 8.x；记录保存为 UTC，服务端按 `Asia/Shanghai` 计算日期边界。

```text
entry/src/main/ets/
├─ api/                 # 集中 HTTP 客户端
├─ components/          # 液体动画、导航和记录行
├─ config/              # 唯一 API 地址配置
├─ models/              # API、统计和提醒模型
├─ pages/views/         # 首页、统计/月历、我的设置
├─ services/            # 本地滚动提醒与 Preferences
└─ store/               # 所有页面共享的状态和统一刷新
server/
├─ src/repositories/    # Mock、MySQL、未配置 Repository
├─ src/waterService.js  # 日期详情、动态目标和统计
├─ src/streakService.js # 当前/最长连续达标计算
├─ sql/init.sql         # 可重复执行的数据库初始化
└─ test/                # 核心 API 与 Mock 冒烟测试
```

## 服务端启动

需要 Node.js 20 或更高版本。

```powershell
cd server
npm install
Copy-Item .env.example .env
npm.cmd start
```

环境变量：

```env
DATA_MODE=mock
SERVER_PORT=3000
APP_TIME_ZONE=Asia/Shanghai
DEFAULT_USER_ID=1

DB_HOST=
DB_PORT=3306
DB_NAME=helema
DB_USER=
DB_PASSWORD=
```

- `DATA_MODE=mock`：无需数据库，服务重启后数据清空。
- `DATA_MODE=mysql`：使用 MySQL 持久化；缺少配置时服务仍启动，health 返回 `not_configured`。
- `.env` 和真实数据库凭据不会提交到仓库。

## MySQL 初始化

`server/sql/init.sql` 会创建并选择 `helema` 数据库，然后幂等创建：

- `users`：用户。
- `water_records`：每次打卡的独立 UTC 记录和幂等键。
- `user_daily_goals`：按生效日期保存目标，唯一键为 `(user_id, effective_date)`。

MySQL 模式必须保留 `DEFAULT_USER_ID` 对应的 `users` 行。health 会同时检查数据库连接、必需表和默认用户；若默认用户缺失，应重新执行 `init.sql`，否则打卡写入会被 `water_records.user_id` 外键拒绝。

执行：

```powershell
cd server
mysql -h 127.0.0.1 -P 3306 -u root -p --execute="source C:/完整路径/server/sql/init.sql"
```

如果使用其他数据库名，需要同步修改 SQL 顶部的 `CREATE DATABASE`/`USE` 和 `.env` 的 `DB_NAME`。脚本可以连续执行；同一用户同一天重复保存目标只会更新原行。

## REST API

成功响应统一为 `{ "success": true, "data": ... }`，失败响应统一为 `{ "success": false, "error": { "code", "message" } }`。

- `GET /api/health`
- `GET /api/water/today`
- `GET /api/water/history?days=7`
- `GET /api/water/settings`
- `PUT /api/water/settings`
- `POST /api/water/check-in`
- `DELETE /api/water/records/:id`
- `GET /api/water/day?date=YYYY-MM-DD`
- `GET /api/water/stats?period=week|month&anchor=YYYY-MM-DD`

`PUT /settings` 只更新当天目标。`POST /check-in` 不再接收自定义水量，返回 `created`、`idempotentReplay`、`recordId` 和最新 `today`；只有 `created=true` 时客户端显示五秒撤销。

每日完成状态、周月达标和连续天数只按次数计算。新记录内部固定保存 250ml 兼容值，首页和设置页不再提供单次水量配置；历史日期详情仍可展示已有记录中的水量数据。

## 客户端与网络配置

API 候选地址只在 [AppConfig.ets](./entry/src/main/ets/config/AppConfig.ets) 中维护。应用启动时逐个请求 `/api/health`，只使用实际成功的地址。`10.0.2.2` 只是待验证的模拟器候选，失败后会继续尝试 VMware 宿主机地址和电脑 WLAN IPv4。

VMware 联调时应填写宿主机对应虚拟网卡的 IPv4，而不是虚拟机自身 IP。真机需与电脑位于可互访的同一局域网，并确保 TCP 3000 入站放行。

`module.json5` 已声明：

- `ohos.permission.INTERNET`
- `ohos.permission.PUBLISH_AGENT_REMINDER`

当前 API 24 schema 不接受先前尝试的 `app.network.cleartextTraffic` 字段，因此未保留无效配置。开发机 HTTP 服务可用；模拟器/真机是否允许明文 HTTP 必须在实际设备上通过 health 验证。

构建 debug HAP：

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon
```

项目未配置命令行签名，Hvigor 会生成未签名 debug HAP；设备运行可使用 DevEco Studio 自动签名。

### DevEco 安装成功但 Ability 启动失败

如果日志显示 HAP 已安装，但 `aa start` 报 `10104001`，先对比日志中的 `Launching <bundleName>` 与 `AppScope/app.json5` 的 `bundleName`。修改包名后，`clean` 只清理构建产物，不会刷新 DevEco 的项目同步模型；如果日志仍启动旧包名，应执行完整 Hvigor 同步：

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe' `
  'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js' --sync
```

随后确认 `.hvigor/outputs/sync/output.json` 中的 `BUNDLE_NAME` 已更新，再在 DevEco 中重新同步或重新打开项目。不要通过反复 `clean` 处理此类运行配置缓存问题。

## 功能说明

- 首页液体进度使用服务端动态目标；设置或删除导致完成状态变化时只调整液位。
- 只有新打卡首次跨越目标时播放完成庆祝；目标修改、删除、撤销和幂等重放不会误播。
- 首页只保留一个完整宽度的玻璃打卡按钮，已移除水量选择和右上角快捷键。
- 新打卡提供五秒撤销；月历日期详情支持左滑删除并二次确认。
- 统计页按周一至周日或自然月一次加载完整连续日期；月历不会逐日请求。
- 当前连续在今天未达标时从昨天计算，最长连续覆盖所有聚合历史。

## 本地提醒

提醒使用一次性 Calendar Reminder 和两日滚动窗口：每次校准维护今天剩余时间槽与明天全部时间槽。当天达标只取消今天剩余项，明天项继续保留；删除记录或提高目标后会补回今天未来时间槽。

Preferences 中每项保存 `reminderId`、`scheduledAt`、`slotKey` 和 `configVersion`。设置变化只取消失效项，`slotKey` 防止重复发布。提醒间隔提供 60、120、180 分钟；第三方应用最多有 30 个有效代理提醒，保存前会校验两日窗口容量。

如果系统返回 `1700002`，客户端会清空当前应用的代理提醒、逐条补充取消残留项、轮询确认系统数量归零，并按 2、4、6 秒分段等待配额释放后重试。失败提示会附带运行时包名、清理前数量、清理后数量和本次计划数量；当公开列表为 0 但第一条仍被拒绝时，提示会明确标记为系统内部配额与公开列表不一致，而不是权限问题。

界面区分以下真实状态：

- `disabled`
- `enabled`
- `permission_required`
- `system_notification_disabled`
- `publish_failed`
- `partially_scheduled`

只有系统授权有效且所有目标槽实际发布成功后才显示“已启用”。提醒按设备本地时钟触发，服务端的今日和统计日期仍按 `Asia/Shanghai`。

## App 图标

- 原始素材：[app_icon_source.png](./design-references/app_icon_source.png)
- 1024 主图标：`app_icon_1024.png`
- 启动图标：`start_icon.png`

图标没有按近黑色像素直接抠图，而是重建完整蓝色渐变方形背景交给系统蒙版裁切。`design-references/icon-previews` 保留 96、72、48px 检查图；48px 下水滴、水杯和对勾仍可辨认。

图标母版通过内置 imagegen 编辑流程生成，使用的最终提示重点为：延展原有蓝色渐变到完整方形画布，仅替换黑色四角，保持中央白色水滴、水杯、液面、气泡和对勾的几何、位置与比例不变，不添加文字或新元素。

## 2026-07-21 实际验证结果

- 后端自动测试：通过，13 项测试覆盖 health、动态设置、幂等打卡、删除、日期详情、周月连续日期、历史目标、连续达标和错误结构。
- Mock API 冒烟：通过，覆盖 health、settings、check-in、day、history、month stats 和 delete。
- MySQL 初始化：`init.sql` 在端口 3308 的开发数据库连续执行两次成功；默认用户 1 条、重复目标 0 条。当前迁移不再创建或写入单次水量设置表。
- MySQL API 冒烟：通过，health 为 `connected`，settings、check-in、day、week、month、delete 均返回预期结构；冒烟打卡随后已删除。
- 宿主机网络：Node 正在 `0.0.0.0:3000` 监听，MySQL 正在 `0.0.0.0:3308` 监听；`127.0.0.1`、三个 VMware 宿主机 IPv4 和当前 WLAN IPv4 的 health 均返回 `database.status=connected`。
- HarmonyOS API 24 debug HAP：加入地址逐项诊断与提醒配额延迟恢复后重新构建通过。
- DevEco 实际使用的 `hdc` 与用户 SDK 中的 `hdc` 均返回 `[Empty]`，因此尚不能从设备侧判断虚拟机静态 IP、HTTP 请求错误或系统 ReminderAgent 数据库；系统提醒、明文 HTTP、挖孔屏布局和完整交互仍不宣称通过。

设备联调步骤：

1. 启动 API 并在电脑上确认 `GET /api/health`。
2. 执行 `hdc list targets`，确认设备已连接。
3. 在设备浏览器或应用中验证候选宿主机/LAN 地址的 health。
4. 验证首页打卡、五秒撤销、删除确认、目标反转、周月统计和月历详情。
5. 开启通知授权，验证今天/明天提醒、重复校准不重复、达标只取消今天以及六种提醒状态。

## 暂未实现与已知限制

- 暂未实现登录、多用户切换、社交、多设备同步、云端推送、复杂健康分析和 AI 建议。
- Mock 模式重启后数据清空。
- 滚动提醒保障今天和明天；若应用连续超过两天完全未被系统或用户唤起，后续窗口无法继续扩展。
- 当前环境没有连接模拟器或真机，设备端验收仍待完成。
# 账号登录与旧数据迁移

客户端只通过 Node.js REST API 访问数据，不直接连接 MySQL。第一版账号由本地脚本管理，
没有公开注册、短信验证码、找回密码、第三方登录或管理后台。

生产或局域网 MySQL 模式必须设置 `ACCESS_TOKEN_SECRET`（使用足够长的随机值），并配置
`DATA_MODE=mysql`、`DB_HOST`、`DB_PORT`、`DB_NAME`、`DB_USER`、`DB_PASSWORD`。
Access Token 默认 30 分钟，Refresh Token 默认 30 天，可分别通过
`ACCESS_TOKEN_TTL_SECONDS` 和 `REFRESH_TOKEN_TTL_SECONDS` 调整。

先重复执行安全的初始化脚本 `server/sql/init.sql`。密码从标准输入读取，脚本不会回显或
输出明文密码：

```powershell
'A-strong-password1' | npm.cmd run account -- create --phone 13800000000 --nickname 喝水用户
'A-new-password2' | npm.cmd run account -- change-password --phone 13800000000
npm.cmd run account -- disable --phone 13800000000
npm.cmd run account -- enable --phone 13800000000
npm.cmd run account -- list
```

旧版本固定 `DEFAULT_USER_ID`（默认值为 `1`）下的饮水记录和目标不会自动归给任意新账号。
创建目标账号后，执行以下命令把旧记录明确归属给该账号：

```powershell
npm.cmd run account -- migrate-default --to-phone 13800000000 --legacy-user-id 1
```

该迁移在事务中执行且可重复运行；重复执行不会复制饮水记录或目标。迁移后，原
`DEFAULT_USER_ID=1` 的 `water_records` 与 `user_daily_goals` 均归属于
`--to-phone` 指定的账号。服务端业务接口不再读取 `DEFAULT_USER_ID`，也不接受客户端
传入 `userId`。

## 外观与桌面卡片

“我的设置”支持跟随系统、浅色和深色三种外观。页面使用 `base/dark` 下的统一语义颜色，
深色背景为深蓝黑；启动窗口也提供对应深色资源，避免纯白闪屏。

中型 `2×4` 桌面卡片名为 `water_card`。卡片平时读取应用同步写入的本地缓存；点击右侧
水杯按钮会由 FormExtension 使用 Asset Store 中的安全会话调用 Node.js REST API 完成一次
打卡，仍然不会直接连接 MySQL。点击左侧进度圈打开应用，不再显示额外的“打开应用”按钮。
应用在登录、启动完成、打卡、撤销、删除、修改目标和退出登录后刷新缓存；网络请求开始前
把现有缓存标记为“可能非最新”，成功后写入新的更新时间。退出登录会清空 Asset Store
中的 Token 和卡片个人数据，不删除服务端饮水记录。

构建命令：

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe' `
  'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js' `
  --mode module -p product=default -p buildMode=debug assembleHap
```

卡片尺寸、安全区、文字截断、点击跳转、浅深色切换、Asset Store 持久化和主动刷新必须在
HarmonyOS 真机上完成最终验收；模拟器或仅编译成功不能替代真机验收。
#   H e l e M a  
 