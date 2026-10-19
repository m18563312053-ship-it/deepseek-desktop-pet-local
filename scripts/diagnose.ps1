$ErrorActionPreference = 'Stop'
$configPath = Join-Path $env:APPDATA 'dsh-pet-standalone-webm-chat\config.json'

Write-Host 'Ollama 服务：'
$tags = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 10
$tags.models | Select-Object name, size | Format-Table -AutoSize

Write-Host '桌宠配置：'
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$provider = $config.chat.providers.'openai-main'
[pscustomobject]@{
    Enabled = $config.chat.enabled
    Endpoint = $provider.base_url + $provider.chat_path
    Model = $provider.model
    Timeout = $provider.timeout
    MaxTokens = $provider.max_tokens
} | Format-List

Write-Host '接口测试：'
$body = @{
    model = $provider.model
    messages = @(@{ role = 'user'; content = 'Reply exactly: OK' })
    stream = $false
    max_tokens = 512
    temperature = 0
} | ConvertTo-Json -Depth 6 -Compress
$reply = Invoke-RestMethod -Uri ($provider.base_url + $provider.chat_path) -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 180
if ([string]::IsNullOrWhiteSpace([string]$reply.choices[0].message.content)) {
    throw '接口可连接，但模型没有返回正文。'
}
Write-Host ('成功：' + $reply.choices[0].message.content.Trim()) -ForegroundColor Green

