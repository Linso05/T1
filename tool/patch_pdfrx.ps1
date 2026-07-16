<#
.SYNOPSIS
  把 pub 缓存里 pdfrx 的 pdfium 二进制下载地址改走 gh-proxy.com 镜像。

.DESCRIPTION
  pdfrx 的 android/CMakeLists.txt 会在构建时从 GitHub 下载 libpdfium.so。
  国内直连 GitHub 常常失败(下成 0 字节),导致 `[CXX1429]` 构建报错。
  本脚本把下载 URL 换成镜像并关掉证书校验,幂等可重复执行。

  什么时候需要跑:
    - 换机 / 重装 Flutter 后
    - `flutter pub cache repair` 或删过 pub 缓存后
    - 升级 pdfrx 版本后
  跑一次即可,之后 `flutter build apk` 正常。`flutter clean` 不影响本补丁
  (补丁在 pub 缓存里,不在项目 build 目录)。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\patch_pdfrx.ps1
#>

$ErrorActionPreference = 'Stop'

# pub 缓存位置:优先 PUB_CACHE,否则 Windows 默认 %LOCALAPPDATA%\Pub\Cache
$roots = @()
if ($env:PUB_CACHE) { $roots += $env:PUB_CACHE }
$roots += (Join-Path $env:LOCALAPPDATA 'Pub\Cache')
$roots += (Join-Path $env:APPDATA 'Pub\Cache')

$patched = 0
$found = 0

foreach ($root in ($roots | Select-Object -Unique)) {
    $glob = Join-Path $root 'hosted\pub.dev\pdfrx-*\android\CMakeLists.txt'
    foreach ($cm in (Get-ChildItem -Path $glob -ErrorAction SilentlyContinue)) {
        $found++
        $text = Get-Content -Raw -Encoding UTF8 $cm.FullName

        if ($text -match 'gh-proxy\.com') {
            Write-Host "已是镜像,跳过: $($cm.FullName)"
            continue
        }

        # 1) URL 加镜像前缀(仅当还是直连 github 时,幂等)
        $text = [regex]::Replace(
            $text,
            '(file\(DOWNLOAD\s+)https://github\.com/bblanchon/pdfium-binaries',
            '${1}https://gh-proxy.com/https://github.com/bblanchon/pdfium-binaries')

        # 2) 给该 DOWNLOAD 关掉 TLS 校验(镜像偶发证书问题),幂等
        $text = [regex]::Replace(
            $text,
            '(\$\{PDFIUM_RELEASE_DIR\}/\$\{PDFIUM_ARCHIVE_NAME\}\.tgz)\)',
            '${1} TLS_VERIFY OFF)')

        Set-Content -Path $cm.FullName -Value $text -Encoding UTF8 -NoNewline
        Write-Host "已打补丁: $($cm.FullName)"
        $patched++
    }
}

if ($found -eq 0) {
    Write-Warning "没找到 pdfrx 的 CMakeLists.txt。先跑 `flutter pub get`,或检查 PUB_CACHE。"
    exit 1
}
Write-Host ""
Write-Host "完成:发现 $found 处,新打补丁 $patched 处。现在可以 flutter build apk。"
