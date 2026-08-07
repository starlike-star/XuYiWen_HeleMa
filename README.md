# 喝了吗

“喝了吗”是一款基于 HarmonyOS 的每日喝水打卡应用，帮助用户以简单、持续的方式记录饮水次数、查看完成情况，并通过统计、连续达标和系统提醒建立稳定的喝水习惯。

本项目已完成客户端、Node.js REST API、MySQL 持久化、账号会话、系统提醒和桌面卡片端的主要开发工作，可作为局域网或本地环境交付验收。

## 交付内容

- HarmonyOS 手机端应用：ArkTS、ArkUI、Stage 模型，API 24。
- Node.js 服务端：Express、MySQL/Mock 双数据模式。
- MySQL 初始化脚本和账号管理脚本。
- 登录、Token 刷新、退出登录和账号状态管理。
- 今日喝水打卡、五秒撤销、历史记录删除和动态每日目标。
- 周统计、月统计、月历详情、当前连续达标和最长连续达标。
- 基于 Calendar Reminder 的本地滚动提醒。
- 跟随系统、浅色、深色三种外观模式。
- 我们设计并实现了 HarmonyOS 桌面卡片端，支持从桌面查看进度并直接完成一次打卡。

## 产品功能

### 手机端

- 首页展示今日已完成次数、目标次数、进度和最近一次记录。
- 默认每日目标为 8 次，可按生效日期调整为 1～30 次。
- 每次新打卡按 250 ml 兼容值保存，完成状态和统计以打卡次数为准。
- 新打卡支持五秒撤销；历史日期详情支持删除记录并二次确认。
- 统计页按完整周或自然月展示连续日期，月历页支持查看指定日期详情。
- 目标变化、删除和撤销会立即重新计算当天完成状态及连续达标数据。

### 桌面卡片端

桌面卡片名称为 `water_card`，采用 HarmonyOS 中型 `2×4` 尺寸设计：

- 左侧进度圈展示今日进度，点击后打开应用。
- 右侧水杯按钮直接执行一次喝水打卡。
- 卡片显示今日次数/目标、上次打卡时间和缓存更新时间。
- 未登录时展示登录引导，不显示个人饮水数据。
- 卡片通过本地缓存展示快照，由 `FormExtensionAbility` 处理桌面事件并调用 REST API，不直接连接 MySQL。
- 登录、启动完成、打卡、撤销、删除、修改目标和退出登录后会主动刷新卡片。
- 会话凭据保存在 Asset Store；退出登录会清理本地 Token 和卡片个人数据，但不会删除服务端记录。
- 网络请求期间若数据可能过期，卡片会标记“可能非最新”，避免将旧缓存误认为实时数据。

卡片相关实现位于：

```text
entry/src/main/ets/widget/pages/WaterCard.ets
entry/src/main/ets/widget/WaterFormAbility.ets
entry/src/main/ets/services/WidgetCacheService.ets
entry/src/main/resources/base/profile/form_config.json
```

## 项目结构

```text
entry/src/main/ets/
├─ api/                 # REST API 客户端
├─ components/          # 液体动画、导航、记录行等通用组件
├─ config/              # 客户端 API 地址候选配置
├─ models/              # API、统计和提醒模型
├─ pages/views/         # 首页、登录、历史/月历、统计、设置
├─ services/            # 账号会话、Asset Store、主题、提醒和卡片缓存
├─ store/               # 页面共享状态和统一刷新
└─ widget/              # 桌面卡片页面和 FormExtension
server/
├─ src/auth/            # 账号、密码和 Token 服务
├─ src/repositories/    # Mock、MySQL 和未配置 Repository
├─ src/waterService.js  # 今日详情、动态目标和统计
├─ src/streakService.js # 连续达标计算
├─ scripts/account.js   # 账号管理和旧数据迁移
├─ sql/init.sql         # 可重复执行的数据库初始化脚本
└─ test/                # API、账号和 Mock 测试
```

## 服务端启动

需要 Node.js 20 或更高版本。

```powershell
cd server
npm install
Copy-Item .env.example .env
npm.cmd start
```

开发环境可使用 Mock 模式：

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
- `DATA_MODE=mysql`：使用 MySQL 持久化；必须配置数据库连接和 `ACCESS_TOKEN_SECRET`。
- 服务端按 `Asia/Shanghai` 计算业务日期，数据库中的记录保存为 UTC。
- `.env` 和真实数据库凭据不得提交到仓库。

## MySQL 初始化与账号

初始化脚本会创建 `helema` 数据库以及用户、饮水记录、每日目标和会话相关表，脚本可以重复执行：

```powershell
cd server
mysql -h 127.0.0.1 -P 3306 -u root -p --execute="source C:/完整路径/server/sql/init.sql"
```

MySQL 模式下，账号由本地管理员创建，客户端不提供公开注册、短信验证码、找回密码或第三方登录：

```powershell
'A-strong-password1' | npm.cmd run account -- create --phone 13800000000 --nickname 喝水用户
'A-new-password2' | npm.cmd run account -- change-password --phone 13800000000
npm.cmd run account -- disable --phone 13800000000
npm.cmd run account -- enable --phone 13800000000
npm.cmd run account -- list
```

旧版本固定用户的数据需要明确迁移到新账号：

```powershell
npm.cmd run account -- migrate-default --to-phone 13800000000 --legacy-user-id 1
```

迁移在事务中执行，可重复运行，不会复制已有饮水记录或目标。

## REST API

成功响应格式为 `{ "success": true, "data": ... }`，失败响应格式为 `{ "success": false, "error": { "code", "message" } }`。

公开接口：

- `GET /api/health`
- `POST /api/auth/login`
- `POST /api/auth/refresh`

登录后接口：

- `GET /api/auth/me`
- `POST /api/auth/logout`
- `GET /api/water/today`
- `GET /api/water/history?days=7`
- `GET /api/water/settings`
- `PUT /api/water/settings`
- `POST /api/water/check-in`
- `DELETE /api/water/records/:id`
- `GET /api/water/day?date=YYYY-MM-DD`
- `GET /api/water/stats?period=week|month&anchor=YYYY-MM-DD`

打卡接口支持 `Idempotency-Key`，可避免网络重试造成重复记录；客户端使用 Bearer Token 访问用户数据，服务端不会接受客户端传入的 `userId`。

## 客户端联调与构建

客户端 API 地址集中维护在 [AppConfig.ets](./entry/src/main/ets/config/AppConfig.ets)。应用启动时会依次请求 `/api/health`，选择实际可用的服务地址。

- 模拟器可尝试 `10.0.2.2` 或对应的宿主机地址。
- VMware 联调时填写宿主机虚拟网卡 IPv4，不要填写虚拟机自身 IP。
- 真机需要与开发电脑处于可互访的同一局域网，并放行 TCP 3000 入站访问。
- 应用声明了 `ohos.permission.INTERNET` 和 `ohos.permission.PUBLISH_AGENT_REMINDER`。

构建未签名 debug HAP：

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  assembleHap --mode module -p product=default -p module=entry@default `
  -p buildMode=debug --no-daemon
```

项目未配置命令行签名。使用 DevEco Studio 运行到设备时，可由 IDE 自动签名。

## 本地提醒

提醒采用一次性 Calendar Reminder 和两日滚动窗口：

- 每次校准维护今天剩余时间槽和明天全部时间槽。
- 当天达标只取消今天的剩余提醒，明天的提醒继续保留。
- 删除记录或提高目标后，会补回今天尚未到时间的提醒槽。
- 支持 60、120、180 分钟提醒间隔，并对第三方应用提醒配额进行校验。
- 客户端区分 `disabled`、`enabled`、`permission_required`、`system_notification_disabled`、`publish_failed` 和 `partially_scheduled` 等状态。

若应用连续超过两天没有被系统或用户唤起，滚动窗口无法继续扩展，这是 HarmonyOS 本地提醒方案的已知限制。

## 验证记录与交付边界

已有验证包括：

- Node.js 后端自动测试：覆盖 health、登录与 Token、动态目标、幂等打卡、删除、日期详情、周/月统计、连续达标、错误结构和旧数据迁移。
- Mock API 冒烟测试：覆盖登录、health、settings、check-in、day、history、stats 和 delete。
- MySQL 初始化脚本连续执行和 MySQL API 冒烟验证。
- HarmonyOS API 24 debug HAP 构建验证。

服务端验证命令：

```powershell
cd server
npm test
npm run smoke
```

最终交付前仍需在 HarmonyOS 真机上验收以下项目：

- 桌面卡片的 `2×4` 尺寸、安全区、文字截断和点击跳转。
- 卡片浅色/深色切换、Asset Store 持久化、主动刷新和直接打卡。
- 系统通知授权、今天/明天提醒、重复校准、达标取消和提醒失败状态。
- 明文 HTTP、局域网连通性、挖孔屏布局以及完整端到端交互。

当前版本暂不包含公开注册、多用户切换、社交、多设备同步、云端推送、复杂健康分析和 AI 建议。

## 图标资源

- 原始素材：[app_icon_source.png](./design-references/app_icon_source.png)
- 应用主图标：[app_icon_1024.png](./entry/src/main/resources/base/media/app_icon_1024.png)
- 启动图标：[start_icon.png](./entry/src/main/resources/base/media/start_icon.png)

图标采用完整蓝色渐变方形背景，并保留中央白色水滴、水杯、液面、气泡和对勾元素，交由系统蒙版裁切。
