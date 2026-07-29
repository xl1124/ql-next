# QL-Next

QL-Next 是一个基于 Flutter 开发的 QingLong 移动端管理工具，面向 Android 手机和平板，也保留了 iOS 与 Web 平台配置。

项目通过 QingLong 后端 API 管理任务、环境变量、配置文件、脚本、依赖、订阅、日志和系统设置。应用不内置 QingLong 服务端，使用前需要准备一个可以从设备访问的 QingLong 实例。

## 项目状态

- 应用名称：QL-Next
- Android 包名：com.qlnext.android
- 当前版本来源：pubspec.yaml 的 version 字段
- Android 构建架构：arm64-v8a 与 armeabi-v7a
- UI 框架：Flutter + Material 3
- 数据通信：HTTP/HTTPS + QingLong REST API
- 认证方式：QingLong Token，使用 Bearer Authorization 请求头
- Android 构建签名：优先使用环境变量 `KEYSTORE_PATH` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD` 配置的正式签名，未配置时自动回退为调试签名

## 功能概览

### 登录与账号

- QingLong 服务器地址、用户名和密码登录
- 二因素认证登录
- 登录失败和网络错误提示
- 多账号保存、切换和删除
- 当前账号信息展示
- 退出登录
- Token 使用安全存储保存

### 主导航

应用主界面包含以下五个入口：

| 入口 | 功能 |
| --- | --- |
| 任务 | 定时任务列表、搜索、状态筛选、创建、编辑、运行、停止、启用、禁用、置顶和删除 |
| 环境 | 环境变量的创建、编辑、启用、禁用、删除、批量操作、导入和导出 |
| 仪表 | 任务概览、运行趋势、耗时任务、系统信息和 QingLong 统计数据 |
| 配置 | 配置文件列表、查看、编辑、保存和重新加载 |
| 设置 | 账号、外观、通知、脚本、依赖、订阅、日志、安全、服务器和应用设置 |

### 设置页面

- 主题模式：跟随系统、浅色、深色
- 强调色切换
- 玻璃效果开关
- 通知渠道配置
- 脚本目录浏览、创建、编辑、运行、停止、重命名、上传、下载和删除
- Node.js、Python 3、Linux 依赖管理
- 依赖安装、重装、取消、删除和日志查看
- 订阅创建、编辑、启用、禁用、运行、停止、删除和日志查看
- 任务日志列表、搜索、查看和下载
- 登录日志查看
- QingLong 服务器配置和健康状态
- QingLong 更新检查、更新、重载和系统数据导入导出
- 两步验证启用和关闭
- 用户名和密码修改
- QingLong 应用 Client ID、Client Secret 管理
- 动态读取当前安装包版本号
- 酷安主页跳转

### UI 设计

- Material 3 颜色系统
- 可切换的浅色、深色和跟随系统主题
- 基于强调色的统一卡片和操作按钮
- 玻璃背景和统一渐变背景
- 设置子页面统一底部弹窗外壳
- 设置子页面统一拖动条、搜索框、空状态和错误状态
- 错误状态显示后端返回的错误说明和重试按钮
- 页面空状态统一图标、标题、说明和操作按钮间距

## 后端要求

QL-Next 需要连接 QingLong 服务端，应用本身不提供服务端能力。

建议准备：

- 一台已经正常运行的 QingLong 实例
- 一个可以从 Android 设备访问的 HTTP 或 HTTPS 地址
- QingLong 登录账号
- 如果启用了两步验证，准备对应的验证器或验证码

首次打开应用时，在登录页填写：

1. QingLong 服务器地址，例如 http://192.168.1.20:5700
2. QingLong 用户名
3. QingLong 密码

服务器地址可以填写带协议或不带协议的形式。应用会对常见地址进行规范化处理。

### Android 网络地址说明

Android 设备中的 127.0.0.1 指向设备自身，不是开发电脑或 QingLong 服务器。

- Android Studio 模拟器访问宿主机：通常使用 10.0.2.2:5700
- 真机访问局域网 QingLong：使用电脑的局域网 IP，例如 192.168.1.20:5700
- 真机访问公网服务：使用可访问的域名或公网 IP

### HTTP 与 HTTPS

当前 Android 配置允许明文 HTTP，用于兼容局域网内常见的 QingLong 部署方式。生产环境更推荐使用 HTTPS，尤其是在公网或不可信网络中使用时。

不要把 QingLong 管理接口直接暴露到公网。建议通过反向代理、VPN、Tailscale、内网穿透访问控制或其他安全网络方案保护服务端。

## 环境要求

### 必需环境

- Flutter SDK
- Dart SDK，版本范围由 pubspec.yaml 的 environment.sdk 定义
- Android SDK
- Android SDK Platform、Build Tools 和对应 Android NDK
- Java 17
- Git

项目当前 Android Gradle 配置使用：

- Java source/target：17
- Kotlin JVM target：17
- Android Gradle Plugin：项目 android/settings.gradle.kts 中声明的版本
- Android 包名：com.qlnext.android
- 最低 SDK、目标 SDK：跟随 Flutter Gradle 插件提供的版本

### 推荐检查

~~~bash
flutter doctor -v
flutter --version
dart --version
java -version
~~~

如果本机 Flutter 不在 PATH 中，也可以使用绝对路径，例如：

~~~bash
/opt/flutter/bin/flutter doctor -v
~~~

## 获取项目

~~~bash
git clone <your-repository-url>
cd qinglong_flutter
~~~

安装依赖：

~~~bash
flutter pub get
~~~

首次运行前建议执行：

~~~bash
flutter doctor -v
flutter analyze
flutter test
~~~

## 本地运行

查看可用设备：

~~~bash
flutter devices
~~~

运行 Debug 版本：

~~~bash
flutter run
~~~

指定设备运行：

~~~bash
flutter run -d <device-id>
~~~

运行过程中可以在登录页填写 QingLong 地址和账号。应用会把登录信息保存到本地，后续启动时恢复登录状态。

## Android 构建

### GitHub Actions 自动构建

项目默认通过 GitHub Actions 编译 Android Release APK，不再依赖本机 Android 构建环境。工作流文件位于 `.github/workflows/android.yml`，在推送到 `main` 分支时自动运行，也可以在 GitHub Actions 页面手动触发。

每次工作流会依次执行依赖安装、Dart 分析、Flutter 测试，然后分别生成并上传：

- `QL-Next-arm64-v8a.apk`：64 位 ARM 设备
- `QL-Next-armeabi-v7a.apk`：32 位 ARM 设备

构建完成后，会自动将每个 APK 作为独立 Artifact 上传（可在运行记录的 Artifacts 区域单独下载），同时发布到 GitHub Releases 的 `continuous` 标签页，最新构建的 APK 始终可直接下载。工作流支持通过 GitHub Secrets 配置正式签名（详见下方 [Release 签名](#release-签名) 说明），未配置 Secrets 时自动回退为调试签名。

### 本机备用构建

如需在本机临时构建两个 ABI，可以使用：

~~~bash
flutter build apk \
  --release \
  --split-per-abi \
  --target-platform android-arm,android-arm64
~~~

输出文件：

~~~text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
~~~

工作流通过 `--split-per-abi` 和 `--target-platform android-arm,android-arm64` 选择两个 ARM 架构，不会生成 x86 或 x86_64 版本。Android Gradle 工程不再额外固定 `abiFilters`，避免与 Flutter 的 ABI split 配置冲突。

### 指定版本号构建

版本号由 pubspec.yaml 管理：

~~~yaml
version: 1.0.0+1
~~~

也可以在构建时临时覆盖：

~~~bash
flutter build apk \
  --release \
  --split-per-abi \
  --target-platform android-arm,android-arm64 \
  --build-name=1.0.1 \
  --build-number=2
~~~

应用设置页使用 package_info_plus 动态读取安装包中的版本号和构建号，不在 UI 中写死版本字符串。

### 安装到 Android 设备

确保设备已打开 USB 调试并且 adb devices 可以看到设备：

~~~bash
adb devices
adb install -r build/app/outputs/flutter-apk/app-release.apk
~~~

如果设备已经安装旧包名版本，旧包名是：

~~~text
com.qinglong.qinglong_flutter
~~~

新版本包名为：

~~~text
com.qlnext.android
~~~

由于 Android 将它们视为两个不同应用，必要时需要先卸载旧应用：

~~~bash
adb uninstall com.qinglong.qinglong_flutter
adb install build/app/outputs/flutter-apk/app-release.apk
~~~

卸载会清除旧应用的本地登录状态和本地配置，请确认不再需要旧数据后再执行。

### Release 签名

项目使用环境变量注入签名信息，支持在 GitHub Actions 和本地开发环境中灵活配置签名凭据，未配置时自动回退为调试签名。

#### 生成正式签名密钥

~~~bash
keytool -genkeypair -v \
  -keystore release.keystore \
  -alias release \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=Your Name,OU=Your Org,O=Your Company,L=City,ST=State,C=CN"
~~~

#### GitHub Actions 配置

在仓库 Settings → Secrets and variables → Actions 中配置以下 Secrets：

| Secret | 说明 |
| --- | --- |
| `KEYSTORE_BASE64` | keystore 文件的 Base64 编码：`base64 -w0 release.keystore` |
| `KEYSTORE_PASSWORD` | keystore 密码 |
| `KEY_ALIAS` | 密钥别名（例如 `release`） |
| `KEY_PASSWORD` | 密钥密码 |

配置后每次自动构建都会使用固定密钥签名，APK 签名保持一致，用户可覆盖安装更新。

#### 本机构建配置

将 release.keystore 放到任意安全位置，构建时传入环境变量：

~~~bash
flutter build apk \
  --release \
  --split-per-abi \
  --target-platform android-arm,android-arm64 \
  --build-number=1
~~~

构建前设置环境变量：

~~~bash
export KEYSTORE_PATH=/path/to/release.keystore
export KEYSTORE_PASSWORD=your-keystore-password
export KEY_ALIAS=release
export KEY_PASSWORD=your-key-password
~~~

也可以写成一次性的单行命令：

~~~bash
KEYSTORE_PATH=release.keystore KEYSTORE_PASSWORD=xxx KEY_ALIAS=release KEY_PASSWORD=xxx \
  flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
~~~

> 不要把 keystore 文件或密码提交到 Git。把 release.keystore 添加到 `.gitignore` 中。

## 测试与代码质量

运行静态分析：

~~~bash
dart analyze
~~~

运行全部 Flutter 测试：

~~~bash
flutter test
~~~

当前测试覆盖以下方面：

- 登录页和登录校验
- Token 会话恢复与退出登录
- 仪表盘加载、刷新、空状态和错误状态
- 定时任务列表和任务操作
- 环境变量编辑、启用、禁用、删除和批量操作
- 配置文件查看、编辑、保存和错误处理
- 服务器设置加载、保存、更新和重试
- 账号管理和两步验证入口
- 依赖列表竞态、类型筛选、表单提交和操作锁
- 各页面错误状态和后端错误显示

推荐提交前执行：

~~~bash
dart format lib test
dart analyze
flutter test
~~~

## 项目结构

~~~text
qinglong_flutter/
├── android/                         Android 工程、包名和 ARM ABI 构建配置
├── .github/workflows/android.yml    GitHub Actions Android 构建流程
├── ios/                             iOS 工程配置
├── web/                             Web 应用名称和 Web Manifest
├── lib/
│   ├── app.dart                     应用入口、会话恢复和主题注入
│   ├── data/
│   │   ├── api/
│   │   │   ├── api_client.dart      HTTP 请求、鉴权和网络错误处理
│   │   │   └── qinglong_api.dart    QingLong API 业务封装
│   │   ├── local/
│   │   │   ├── local_storage.dart   登录信息、账号和本地设置存储
│   │   │   └── theme_controller.dart 主题模式、强调色和玻璃效果
│   │   └── models/                  API 数据模型和 JSON 转换
│   ├── theme/                       Material 3 主题和视觉系统
│   └── ui/
│       ├── components/              公共组件、顶部栏、底部导航和状态组件
│       └── screens/
│           ├── login/               登录页面
│           ├── main/                主导航和 IndexedStack
│           ├── dashboard/           仪表盘
│           ├── tasks/               定时任务
│           ├── env/                 环境变量
│           ├── config/              配置文件
│           └── settings/            设置及其子页面
├── test/                            Widget、API、模型和状态测试
├── pubspec.yaml                     Flutter 依赖和应用版本
└── analysis_options.yaml             Dart 静态分析规则
~~~

## 代码架构

### UI 层

页面主要位于 lib/ui/screens，按业务模块拆分。主界面使用 IndexedStack 保留各页面状态，底部导航负责切换任务、环境、仪表、配置和设置。

设置中的脚本、依赖、订阅、日志和服务器配置通过统一的底部弹窗外壳打开，以保证顶栏、拖动条、安全区和背景表现一致。

### API 层

QingLongApi 对 QingLong 服务端 API 进行业务封装，ApiClient 负责：

- 拼接服务器地址
- 注入 Bearer Token
- 发起 GET、POST、PUT、DELETE 和文件上传下载请求
- 解析响应结构
- 统一处理 HTTP 和网络错误

主要 API 业务分类包括：

- 用户登录、退出登录和二因素认证
- 系统信息、系统配置、健康检查、更新和重载
- 任务、环境变量和配置文件
- 脚本、日志、依赖和订阅
- 通知设置、登录日志和 QingLong 应用管理
- 仪表盘统计数据

新增后端功能时，建议先在 lib/data/api/qinglong_api.dart 增加明确的 API 方法和返回模型，再由页面调用，不要在 Widget 中直接拼接请求 URL。

### 本地存储

LocalStorage 负责本地数据：

- 当前服务器地址
- 当前用户名
- 当前登录 Token
- 保存的多个账号
- 主题模式
- 强调色
- 玻璃效果开关

登录 Token 使用 flutter_secure_storage 保存。升级或迁移本地存储字段时，需要考虑旧版本数据迁移逻辑，不要直接删除已有 key。

## 依赖说明

| 依赖 | 用途 |
| --- | --- |
| http | QingLong API 网络请求 |
| shared_preferences | 非敏感本地设置和账号索引 |
| flutter_secure_storage | 登录 Token 等敏感信息存储 |
| file_picker | 脚本、系统数据等文件选择 |
| package_info_plus | 动态读取当前应用版本和构建号 |
| url_launcher | 打开酷安主页等外部链接 |
| cupertino_icons | Cupertino 图标支持 |

项目保留了 path_provider_android 版本覆盖，这是当前 Android 构建环境与相关 JNI 实现之间的兼容性处理，不要在没有验证的情况下删除。

## 常见问题

### 登录时提示无法连接服务器

按以下顺序排查：

1. 确认 QingLong 服务端正在运行。
2. 确认手机或模拟器可以访问服务器地址和端口。
3. 真机不要使用电脑的 127.0.0.1，改用电脑局域网 IP。
4. Android 模拟器访问宿主机时尝试 10.0.2.2。
5. 确认防火墙允许 QingLong 端口访问。
6. 如果使用 HTTPS，确认域名、证书和系统时间正确。

### APK 安装时报 resources.arsc 未压缩或未对齐

Android 11 及以上对 Target SDK 30+ 的 APK 资源存储有要求。项目已经在 Android Gradle 构建流程中加入资源归档修复、4 字节对齐和签名处理。请使用项目的 Release 构建命令生成 APK，不要直接拿中间产物安装：

~~~bash
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
~~~

### 修改了包名后无法覆盖安装旧 APK

包名从 com.qinglong.qinglong_flutter 改为 com.qlnext.android 后，Android 会把它们识别为两个应用。需要卸载旧包，或者保留两个应用并分别登录。

### 登录页仍然显示旧名称

应用显示名称由多个位置共同决定：

- Flutter 应用标题：lib/app.dart
- 登录页品牌文案：lib/ui/screens/login/login_screen.dart
- Android 应用标签：android/app/src/main/AndroidManifest.xml
- iOS 显示名称：ios/Runner/Info.plist
- Web 标题和 Manifest：web/index.html、web/manifest.json

修改后需要重新执行完整构建，已经安装的旧 APK 不会自动更新资源。

### Release 构建很慢或重复出现 Gradle 监听提示

当前开发环境使用了 Flutter、AGP 9 和定制的 Android 资源修复流程，构建过程中可能出现 Flutter 文件监听提示。可以先确认没有其他 Gradle/Flutter 构建进程占用，再重新执行构建命令。不要在多个终端同时运行 Release 构建。

### 如何修改应用版本

修改 pubspec.yaml：

~~~yaml
version: 1.2.0+12
~~~

重新构建后，设置页“关于”中的应用版本会通过 package_info_plus 自动读取新的版本和构建号。

## 发布前检查清单

- [ ] 修改 pubspec.yaml 版本号
- [ ] 确认 Android 包名为 com.qlnext.android
- [ ] 配置 GitHub Secrets（KEYSTORE_BASE64 / KEYSTORE_PASSWORD / KEY_ALIAS / KEY_PASSWORD）用于正式签名
- [ ] 确认 ARM64 与 ARM32 APK 分别在目标设备上安装测试
- [ ] 使用 HTTPS 或受保护的内网连接 QingLong
- [ ] 运行 dart analyze
- [ ] 运行 flutter test
- [ ] 编译 Release APK
- [ ] 在目标 Android 版本和目标设备上手动安装测试
- [ ] 测试登录、退出登录、Token 恢复和多账号切换
- [ ] 测试任务、环境变量、配置文件和设置子页面
- [ ] 测试脚本、依赖、订阅、日志和文件上传下载
- [ ] 测试两步验证、服务器设置和错误重试
- [ ] 确认隐私信息、服务器地址和 Token 没有写入日志或截图

## 贡献指南

欢迎提交 Issue 和 Pull Request。

### 提交功能前

1. 先确认功能是否属于 QingLong 后端已有能力。
2. 阅读对应页面、ViewModel、API 封装和模型代码。
3. 尽量复用现有主题、公共组件和错误处理模式。
4. 对跨页面行为补充 Widget 测试或 API 测试。

### 提交代码前

~~~bash
dart format lib test
dart analyze
flutter test
~~~

UI 修改请特别检查：

- 小屏手机和大屏设备布局
- 深色和浅色主题
- 不同强调色
- 加载、空数据、错误和提交中状态
- 底部弹窗安全区和键盘弹出状态
- 长文本和后端错误说明是否溢出

## 许可证

当前仓库未提供正式 LICENSE 文件。除非仓库后续补充许可证或项目维护者另行声明，代码和资源的使用、复制、修改与分发应遵循仓库所有者的授权范围。

## 致谢

- [Flutter](https://flutter.dev/)
- [Dart](https://dart.dev/)
- [QingLong](https://github.com/whyour/qinglong)
- [Material 3](https://m3.material.io/)
- [plus_plugins](https://github.com/fluttercommunity/plus_plugins)
