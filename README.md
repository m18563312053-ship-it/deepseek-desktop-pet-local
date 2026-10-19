# DeepSeek 本地 AI 桌宠

在 Windows 上一键安装并配置：

- [Ollama](https://ollama.com/) 本地推理
- `deepseek-r1:8b` 模型
- 16K 上下文的 `deepseek-r1:8b-dsh` 配置
- [dsh-pet-indesktop](https://github.com/MerZlin/dsh-pet-indesktop) 对话版桌宠
- 可迁移到指定磁盘的持久会话记忆
- 自定义桌面快捷方式图标

> 本仓库不包含模型权重、第三方安装包、API Key 或任何私人聊天记录。安装脚本会从官方来源下载依赖。

## 环境要求

- Windows 10/11 64 位
- 建议 NVIDIA 独立显卡，8B 模型约需 5.2 GB 磁盘空间
- 首次安装需要联网
- PowerShell 5.1 或更高版本

## 一键安装

以普通用户打开 PowerShell，进入项目目录后运行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

指定记忆目录，例如 E 盘：

```powershell
.\install.ps1 -MemoryPath 'E:\本地ds记忆'
```

安装完成后，双击桌面的 **DeepSeek桌宠**。右键桌宠可选择：

- `AI 对话`：完整聊天窗口
- `快速对话（气泡）`：轻量聊天气泡
- `AI 设置`：查看模型和接口配置

## 本地配置

| 项目 | 值 |
|---|---|
| 接口 | `http://127.0.0.1:11434/v1/chat/completions` |
| 模型 | `deepseek-r1:8b-dsh` |
| 上下文 | 16384 Token |
| 最大输出 | 8192 Token |
| 超时 | 600 秒 |
| API Key | 不需要 |

对话请求只发送到本机 Ollama。若显存不足，Ollama 可能把部分计算转移到 CPU，回复会变慢。

## 持久记忆

脚本会把桌宠的 `sessions` 目录连接到 `MemoryPath\dsh-pet-sessions`。关闭桌宠或重启电脑后，程序会继续读取最近的会话。

注意：

- 等回答完整生成后再关闭程序。
- 点击“新建会话”会创建独立上下文。
- 点击“清空会话”会清除当前会话内容。
- 不要把记忆目录提交到 GitHub，其中可能包含私人对话。

## 故障检查

```powershell
.\scripts\diagnose.ps1
```

若桌宠显示“请求失败”，请确认 Ollama 正在运行，并检查最大输出是否仍为 8192。DeepSeek-R1 可能先生成较长的思考内容，输出上限过低时会在正文出现前结束。

## 上游与许可

本项目是安装与本地配置辅助工具，不是 dsh-pet-indesktop 的官方发行版。

- 桌宠上游：[MerZlin/dsh-pet-indesktop](https://github.com/MerZlin/dsh-pet-indesktop)
- 本地模型运行时：[Ollama](https://ollama.com/)
- 模型：[DeepSeek-R1](https://github.com/deepseek-ai/DeepSeek-R1)

脚本代码使用 MIT License。第三方软件、模型及图片素材分别遵循其自身许可。

