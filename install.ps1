[CmdletBinding()]
param(
    [string]$MemoryPath = (Join-Path $env:USERPROFILE 'Documents\DeepSeekPetMemory'),
    [switch]$SkipOllamaInstall,
    [switch]$SkipPetInstall
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Wait-Ollama {
    for ($i = 0; $i -lt 30; $i++) {
        try {
            Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2 | Out-Null
            return
        } catch {
            Start-Sleep -Seconds 1
        }
    }
    throw 'Ollama 本地服务未能启动。'
}

Write-Step '检查 Ollama'
$ollama = Get-Command ollama.exe -ErrorAction SilentlyContinue
if (-not $ollama) {
    $defaultOllama = Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'
    if (Test-Path -LiteralPath $defaultOllama) {
        $ollamaPath = $defaultOllama
    } elseif ($SkipOllamaInstall) {
        throw '未找到 Ollama，且指定了 SkipOllamaInstall。'
    } else {
        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
        if (-not $winget) { throw '未找到 winget，请先从 https://ollama.com/download 安装 Ollama。' }
        & winget install --exact --id Ollama.Ollama --accept-package-agreements --accept-source-agreements
        $ollamaPath = Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'
    }
} else {
    $ollamaPath = $ollama.Source
}

try {
    Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2 | Out-Null
} catch {
    Start-Process -FilePath $ollamaPath -ArgumentList 'serve' -WindowStyle Hidden
}
Wait-Ollama

Write-Step '下载 DeepSeek-R1 8B'
& $ollamaPath pull 'deepseek-r1:8b'

Write-Step '创建桌宠专用 16K 上下文模型'
$modelFile = Join-Path ([IO.Path]::GetTempPath()) ('deepseek-dsh-' + [guid]::NewGuid().ToString('N') + '.Modelfile')
try {
    [IO.File]::WriteAllText($modelFile, "FROM deepseek-r1:8b`nPARAMETER num_ctx 16384`nPARAMETER temperature 0.6`nPARAMETER top_p 0.95`n", [Text.UTF8Encoding]::new($false))
    & $ollamaPath create 'deepseek-r1:8b-dsh' --file $modelFile
} finally {
    Remove-Item -LiteralPath $modelFile -Force -ErrorAction SilentlyContinue
}

$petExe = Join-Path $env:LOCALAPPDATA 'Programs\dsh-pet-standalone-webm-chat\dsh-pet-standalone-webm-chat.exe'
if (-not $SkipPetInstall) {
    Write-Step '下载并安装 dsh-pet-indesktop 对话版'
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/MerZlin/dsh-pet-indesktop/releases/latest' -Headers @{ 'User-Agent' = 'DeepSeek-Pet-Installer' }
    $asset = $release.assets | Where-Object { $_.name -eq 'dsh-pet-standalone-webm-chat-setup.exe' } | Select-Object -First 1
    if (-not $asset) { throw '最新 Release 中没有找到 Windows Chat 安装包。' }
    $installer = Join-Path ([IO.Path]::GetTempPath()) $asset.name
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installer
    Start-Process -FilePath $installer -ArgumentList '/VERYSILENT','/NORESTART','/SP-' -Wait
}
if (-not (Test-Path -LiteralPath $petExe)) { throw "未找到桌宠程序：$petExe" }

Write-Step '初始化桌宠配置'
Start-Process -FilePath $petExe
Start-Sleep -Seconds 8
Get-Process -Name 'dsh-pet-standalone-webm-chat' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800

$configDir = Join-Path $env:APPDATA 'dsh-pet-standalone-webm-chat'
$configPath = Join-Path $configDir 'config.json'
if (-not (Test-Path -LiteralPath $configPath)) { throw "桌宠没有生成配置文件：$configPath" }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$provider = $config.chat.providers.'openai-main'
$config.chat.enabled = $true
$config.chat.active_provider = 'openai-main'
$provider.name = '本地 DeepSeek'
$provider.base_url = 'http://127.0.0.1:11434'
$provider.chat_path = '/v1/chat/completions'
$provider.model = 'deepseek-r1:8b-dsh'
$provider.timeout = 600.0
$provider.temperature = 0.6
$provider.max_tokens = 8192
$provider.verify_ssl = $false
$provider.thinking = 'auto'
[IO.File]::WriteAllText($configPath, ($config | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))

Write-Step '迁移持久会话记忆'
$memoryRoot = [IO.Path]::GetFullPath($MemoryPath)
New-Item -ItemType Directory -Path $memoryRoot -Force | Out-Null
$memoryRoot = (Resolve-Path -LiteralPath $memoryRoot).Path
$sessionTarget = Join-Path $memoryRoot 'dsh-pet-sessions'
if (-not ([IO.Path]::GetFullPath($sessionTarget).StartsWith($memoryRoot, [StringComparison]::OrdinalIgnoreCase))) {
    throw '记忆目录路径校验失败。'
}
New-Item -ItemType Directory -Path $sessionTarget -Force | Out-Null
$sessionLink = Join-Path $configDir 'sessions'
if (Test-Path -LiteralPath $sessionLink) {
    $sessionItem = Get-Item -LiteralPath $sessionLink -Force
    if (-not ($sessionItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Get-ChildItem -LiteralPath $sessionLink -Force | Copy-Item -Destination $sessionTarget -Recurse -Force
        $backup = Join-Path $configDir ('sessions.local-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Move-Item -LiteralPath $sessionLink -Destination $backup
        New-Item -ItemType Junction -Path $sessionLink -Target $sessionTarget | Out-Null
    }
} else {
    New-Item -ItemType Junction -Path $sessionLink -Target $sessionTarget | Out-Null
}
Copy-Item -LiteralPath $configPath -Destination (Join-Path $memoryRoot 'dsh-pet-config-backup.json') -Force

Write-Step '创建桌面快捷方式'
$iconSource = Join-Path $PSScriptRoot 'assets\deepseek-maid.ico'
$iconTarget = Join-Path $configDir 'deepseek-maid.ico'
if (Test-Path -LiteralPath $iconSource) { Copy-Item -LiteralPath $iconSource -Destination $iconTarget -Force }
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'DeepSeek桌宠.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $petExe
$shortcut.WorkingDirectory = Split-Path -LiteralPath $petExe
if (Test-Path -LiteralPath $iconTarget) { $shortcut.IconLocation = "$iconTarget,0" }
$shortcut.Description = '本地 DeepSeek AI 桌宠'
$shortcut.Save()

Start-Process -FilePath $petExe
Write-Host "`n安装完成。记忆目录：$sessionTarget" -ForegroundColor Green
Write-Host '右键桌宠，选择“AI 对话”即可开始。' -ForegroundColor Green

