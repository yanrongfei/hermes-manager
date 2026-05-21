# 产品需求文档 (PRD)

## 文档列表

| 文档 | 说明 |
|------|------|
| [2026-05-16-hermes-manager-prd-v1.md](../design/2026-05-16-hermes-manager-prd-v1.md) | 主 PRD（v1.0.0，较旧） |
| [2026-05-16-hermes-mobile-prd-v3.md](../design/2026-05-16-hermes-mobile-prd-v3.md) | 移动端 PRD（v3.0） |
| [2026-05-20-hermes-mobile-prd-v3-1-1v1-group-chat.md](2026-05-20-hermes-mobile-prd-v3-1-1v1-group-chat.md) | **1:1 + 群聊合并设计（最新）** |

## 最新文档

推荐使用 `2026-05-20-hermes-mobile-prd-v3-1-1v1-group-chat.md` 作为当前产品需求参考。

### v3.1 核心设计决策

| # | 问题 | 决策 |
|---|------|------|
| 1 | type 字段 | 复用 mode，前端根据 agentIds.length 判断 |
| 2 | 1:1 升级群聊 | v2 再做 |
| 3 | 1:1 关联 | Agent ID（profile_id 作内部优化） |
| 4 | broadcast 消息分组 | 不需要，v1 简化 |
| 5 | Running Tasks 位置 | 只在群聊显示 |
| 6 | 邀请码生成 | 懒生成 |
| 7 | direct 模式忙碌处理 | 直接拒绝（agent_busy 事件） |
