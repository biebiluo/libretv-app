# LibreTV App

自用 LibreTV 套壳 App：一个 WKWebView 壳子，打开自己搭的 LibreTV 服务。

- 首次打开粘贴服务器地址（带 `_token` 的完整链接），存在本机，不上传任何地方。
- 支持内联播放、左右滑返回、下拉刷新，底部有前进/后退/刷新/设置。
- GitHub Actions 自动打包未签名 IPA（见 `.github/workflows/build-ipa.yml`），用直装签名工具安装。

服务器地址不要写进代码里。
