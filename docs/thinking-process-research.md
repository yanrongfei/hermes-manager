# 思考过程(Reasoning)显示技术调研

## 目标
在 hermes-app 中显示 AI agent 的思考过程（reasoning/thinking），类似 hermes-web-ui 中的绿色脉冲圆点 + "思考中..." 效果。

## 问题

hermes-agent gateway 的 HTTP API（`/v1/responses` 和 `/v1/runs`）**不会返回真正的思考内容**。

### `/v1/responses` — 无 reasoning 事件

gateway 在 `run_agent.py` 中使用 `StreamingThinkScrubber`（状态机）剥离所有 thinking 标签后，才将文本通过 `stream_delta_callback` 发出。

被剥离的标签包括：
- `<think...</think...>`
- `<thinking>...</thinking>`
- `<reasoning>...</reasoning>`
- `<thought>...</thought>`
- `<REASONING_SCRATCHPAD>...</REASONING_SCRATCHPAD>`

文件位置：`/Users/yanrongfei/tool/hermes-agent/run_agent.py` 第 7743 行
```python
think_scrubber = getattr(self, "_stream_think_scrubber", None)
if think_scrubber is not None:
    text = think_scrubber.feed(text or "")
```

### `/v1/runs` — reasoning.available 发的是回复内容

`/v1/runs` 的 SSE 流中有 `reasoning.available` 事件，但它的 `text` 字段是 `assistant_message.content` 去掉 XML 标签后的内容，和 `message.delta` 完全一样。

实际测试：
```
message.delta       → {"delta": "2"}
reasoning.available → {"text": "2"}    # 完全相同，不是思考过程
```

文件位置：`/Users/yanrongfei/tool/hermes-agent/run_agent.py` 第 14618-14633 行
```python
_think_text = assistant_message.content.strip()
_think_text = re.sub(r'</?(?:REASONING_SCRATCHPAD|think|reasoning)>', '', _think_text).strip()
self.tool_progress_callback("reasoning.available", "_thinking", _think_text[:500], None)
```

### 真正的 reasoning 为什么没传出来

`run_agent.py` 中有 `_fire_reasoning_delta()` 方法（第 7775 行），通过 `reasoning_callback` 回调发送真正的思考内容。模型（Claude、DeepSeek、MiniMax 等）的 reasoning tokens 会触发此回调。

但 gateway 的 `api_server.py` 在创建 agent 时**没有传入 `reasoning_callback`**（第 859-877 行），所以 reasoning delta 根本不会被发送到 HTTP API 层。

同时，gateway 的 `_make_run_event_callback` 明确注释（第 2824 行）：
```python
# _thinking and subagent_progress are intentionally not forwarded
```

## hermes-web-ui 的解决方案

hermes-web-ui 通过 **Bridge 模式（Unix Socket / TCP）** 连接 hermes-agent，不走 HTTP API。

### 架构

```
hermes-web-ui (client)
  ↕ Socket.IO (/chat-run namespace)
hermes-web-ui (server)
  ↕ Unix Socket (ipc:///tmp/hermes-agent-bridge.sock) 或 TCP (tcp://127.0.0.1:18765)
hermes-agent gateway
```

### 关键文件

| 文件 | 作用 |
|------|------|
| `packages/server/src/services/hermes/agent-bridge/client.ts` | Bridge 客户端，通过 Unix Socket/TCP 连接 agent |
| `packages/server/src/services/hermes/agent-bridge/manager.ts` | Bridge 连接管理 |
| `packages/server/src/services/hermes/run-chat/handle-bridge-run.ts` | 处理 bridge run，转发事件到前端 |
| `packages/client/src/api/hermes/chat.ts` | 前端 Socket.IO 客户端 |

### Bridge 连接流程

1. **连接**：通过 Unix Domain Socket（macOS/Linux）或 TCP（Windows）连接 agent
   - macOS: `ipc:///tmp/hermes-agent-bridge.sock`
   - Windows: `tcp://127.0.0.1:18765`

2. **发送消息**：`bridge.chat(sessionId, message, history, instructions, profile)`
   - 返回 `{run_id, session_id, status}`

3. **轮询输出**：`bridge.streamOutput(runId)` 内部循环调用 `get_output`
   - 每次返回 `{delta, events, cursor, event_cursor, done}`
   - `events` 数组包含结构化事件，**包括真正的 `reasoning.delta` 事件**

4. **事件处理**（`handle-bridge-run.ts` 第 666 行）：
```typescript
} else if (evType === 'reasoning.delta' || evType === 'thinking.delta') {
  const text = String(ev.text || '')
  if (text) {
    message.reasoning = (message.reasoning || '') + text
    message.reasoning_content = (message.reasoning_content || '') + text
  }
  emit(evType, { event: evType, run_id: chunk.run_id, text })
}
```

5. **Bridge 协议**：请求/响应都是一行 JSON + `\n`
   - 请求：`socket.write(JSON.stringify(payload) + '\n')`
   - 响应：读到 `\n` 为止，JSON.parse

### Bridge 支持的操作

| action | 说明 |
|--------|------|
| `chat` | 发送消息，启动 agent run |
| `get_output` | 获取增量输出（delta + events） |
| `get_result` | 获取完整结果 |
| `interrupt` | 中断当前 run |
| `command` | 执行命令（/clear, /compress 等） |
| `status` | 查询 session 状态 |
| `context_estimate` | 估算 token 用量 |

## hermes-server 实现方案

hermes-server 需要像 hermes-web-ui server 一样，通过 Bridge 连接 hermes-agent。

### 实现步骤

1. **新增 `bridge_client.py`** — Python 版本的 AgentBridgeClient
   - 通过 Unix Socket 连接 `ipc:///tmp/hermes-agent-bridge.sock`
   - 实现 `chat()` 和 `stream_output()` 方法
   - 协议：发送 JSON + `\n`，读取一行 JSON 响应

2. **修改 `gateway_channel.py`** — 新增 bridge 连接方式
   - 检测 bridge socket 是否存在，优先使用 bridge
   - bridge 不可用时 fallback 到 HTTP API

3. **修改 `run_executor.py`** — 使用 bridge 获取 reasoning 事件
   - `bridge.chat()` 启动 run
   - `bridge.stream_output()` 轮询获取 delta + events
   - 处理 `reasoning.delta`/`thinking.delta` 事件，转发 WebSocket

### 前置条件

- hermes-agent gateway 需要启动 bridge socket
- 当前 bridge socket 不存在（`/tmp/hermes-agent-bridge.sock` 未找到）
- 可能需要用特定参数启动 gateway 才能开启 bridge

## 当前状态

- hermes-server 已改用 `/v1/runs` API（替代 `/v1/responses`）
- `reasoning.available` 事件能收到但内容是回复本身，不是思考过程
- 前端 thinking block UI 已实现（绿色脉冲、展开/折叠动画）
- 等待 bridge 模式实现后才能真正显示思考内容
