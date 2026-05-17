# GitHub 构建 iOS IPA

项目已经包含 iOS 工程和 GitHub Actions workflow：

- iOS 工程目录：`app/ios`
- Bundle ID：`com.prvchat`
- 应用名称：`PrvChat`
- Workflow：`.github/workflows/ios-ipa.yml`

## 构建未签名 IPA

1. 推送代码到 GitHub 任意分支。
2. 进入 GitHub 仓库页面。
3. 打开 `Actions`。
4. 选择 `Build iOS IPA`。
5. 点击 `Run workflow`，或直接等待 push 自动触发。
6. 构建完成后，在本次 workflow 的 `Artifacts` 里下载 `PrvChat-ios-unsigned`。

未签名 IPA 只用于构建验证和归档，不能直接安装到普通 iPhone 真机。

## 构建可安装签名 IPA

真机可安装 IPA 需要 Apple Developer 账号，并准备以下内容：

- iOS Distribution 证书，导出为 `.p12`
- `.p12` 证书密码
- App ID：`com.prvchat`
- 对应 `com.prvchat` 的 Provisioning Profile
- Apple Team ID
- `ExportOptions.plist`

建议把这些内容放进 GitHub Actions Secrets：

- `IOS_CERTIFICATE_P12_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_EXPORT_OPTIONS_PLIST_BASE64`
- `IOS_KEYCHAIN_PASSWORD`
- `IOS_TEAM_ID`

当前 workflow 默认不做签名，原因是没有上述 Apple 签名材料。拿到证书后，可以在现有 workflow 上增加签名 job，使用 `flutter build ipa --release --export-options-plist=ios/ExportOptions.plist` 产出可安装 IPA。

## iOS 网络和权限

`app/ios/Runner/Info.plist` 已配置：

- 相机权限：视频通话和拍照发送图片
- 麦克风权限：语音消息和语音通话
- 相册权限：选择和保存图片文件
- 本地网络权限：连接私有服务器
- 明文 HTTP 访问：当前服务端仍是 `http://wdsj.fun:10080/api` 和 `ws://wdsj.fun:10081/ws`

后续如果服务端切到 HTTPS/WSS，应关闭 `NSAllowsArbitraryLoads` 并把客户端地址改成 HTTPS/WSS。
