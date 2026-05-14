# Hermes App 自动化测试计划

## 一、技术选型

| 技术 | 用途 |
|------|------|
| **Playwright** | Web 端浏览器自动化测试 (主选) |
| **Flutter Integration Test** | Widget 和页面级别测试 |
| **dio + mockito** | API Mock 测试 |

---

## 二、测试用例 (按优先级 P0→P2)

### P0 - 核心功能 (必须通过)

| ID | 模块 | 测试用例 | 测试步骤 |
|----|------|---------|---------|
| P0-01 | 认证流程 | 登录成功 → 跳转首页 | 1. 打开登录页 2. 输入正确账号密码 3. 点击登录 4. 验证跳转 /home |
| P0-02 | 认证流程 | 错误密码登录失败 | 1. 打开登录页 2. 输入错误密码 3. 点击登录 4. 验证错误提示 |
| P0-03 | 首页导航 | Tab 切换 | 1. 登录后 2. 点击"聊天"Tab 3. 点击"发现"Tab 4. 点击"我的"Tab |
| P0-04 | 聊天功能 | 发送消息 | 1. 进入聊天室 2. 输入消息 3. 点击发送 4. 验证消息显示 |
| P0-05 | 核心链路 | 登录 → 聊天 → 发送消息 | 完整流程覆盖 |
| P0-06 | 启动流程 | App 启动 → 登录页 | 1. 打开 App 2. 验证登录页渲染 |

### P1 - 重要功能

| ID | 模块 | 测试用例 | 测试步骤 |
|----|------|---------|---------|
| P1-01 | 认证流程 | 注册新用户 | 1. 点击 Register 2. 填写表单 3. 提交 4. 验证跳转 |
| P1-02 | 聊天功能 | @mention Agent 选择 | 1. 输入 "@" 触发选择器 2. 选择 Agent 3. 验证插入 |
| P1-03 | 聊天功能 | 消息列表自动滚动 | 1. 发送多条消息 2. 验证列表滚动到底部 |
| P1-04 | 聊天功能 | 停止 Agent 响应 | 1. Agent 思考时 2. 点击"停止"按钮 3. 验证终止 |
| P1-05 | 核心 Widget | 消息气泡渲染 | 1. 进入聊天室 2. 发送消息 3. 验证气泡样式 |
| P1-06 | API Provider | 房间列表获取 | 1. 登录 2. 获取房间列表 3. 验证数据 |
| P1-07 | 路由 | 未登录重定向 | 1. 清除登录状态 2. 访问 /home 3. 验证重定向到登录页 |

### P2 - 次要功能

| ID | 模块 | 测试用例 | 测试步骤 |
|----|------|---------|---------|
| P2-01 | 邀请功能 | 邀请成员 Modal | 1. 进入聊天室 2. 点击邀请图标 3. 验证 Modal 弹出 |
| P2-02 | 附件功能 | 附件上传 Modal | 1. 点击附件按钮 2. 验证弹出图片/拍照/文件选项 |
| P2-03 | WebSocket | 消息实时推送 | 1. 连接 WS 2. 发送消息 3. 验证实时接收 |
| P2-04 | 打字指示 | 打字状态指示器 | 1. 输入文字 2. 验证"正在输入"提示 |

---

## 三、执行状态

| 状态 | 说明 |
|------|------|
| ✅ 已完成 | 已实现并通过 |
| 🔄 进行中 | 正在实施 |
| 📋 待开始 | 排队等待 |

### 当前进度

| ID | 测试用例 | 状态 |
|----|---------|------|
| P0-01 | 登录成功 → 跳转首页 | 🔄 已实现 (p0-auth.spec.ts) |
| P0-02 | 错误密码登录失败 | 🔄 已实现 (p0-auth.spec.ts) |
| P0-03 | Tab 切换 | 🔄 已实现 (p0-navigation.spec.ts) |
| P0-04 | 发送消息 | 🔄 已实现 (p0-chat.spec.ts) |
| P0-05 | 完整链路 | 🔄 已实现 (p0-auth.spec.ts + p0-chat.spec.ts) |
| P0-06 | App 启动 → 登录页 | 🔄 已实现 (p0-auth.spec.ts) |

---

## 四、目录结构

```
hermes-app/
├── tests-e2e/
│   ├── config/
│   │   └── playwright.config.ts     # Playwright 配置
│   ├── pages/
│   │   ├── login.page.ts           # 登录页 POM
│   │   ├── home.page.ts            # 首页 POM
│   │   └── chat.page.ts            # 聊天室 POM
│   └── tests/
│       ├── p0-auth.spec.ts         # P0 认证测试
│       ├── p0-navigation.spec.ts   # P0 导航测试
│       ├── p0-chat.spec.ts         # P0 聊天测试
│       ├── p1-chat.spec.ts         # P1 聊天测试
│       └── p2-features.spec.ts     # P2 功能测试
└── integration_test/               # Flutter 集成测试
```

---

## 五、技术实现

### 5.1 Playwright 配置 (playwright.config.ts)

```typescript
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests-e2e/tests',
  timeout: 30000,
  use: {
    baseURL: 'http://localhost:3000',
    headless: true,
  },
  webServer: {
    command: 'cd hermes-app && flutter run -d chrome --web-port 3000',
    port: 3000,
    reuseExistingServer: true,
  },
});
```

### 5.2 页面对象模型示例 (login.page.ts)

```typescript
import { Page, Locator } from '@playwright/test';

export class LoginPage {
  readonly page: Page;
  readonly usernameInput: Locator;
  readonly passwordInput: Locator;
  readonly loginButton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.usernameInput = page.locator('input[name="username"]');
    this.passwordInput = page.locator('input[name="password"]');
    this.loginButton = page.locator('button[type="submit"]');
  }

  async login(username: string, password: string) {
    await this.usernameInput.fill(username);
    await this.passwordInput.fill(password);
    await this.loginButton.click();
  }
}
```

### 5.3 测试用例示例 (p0-auth.spec.ts)

```typescript
import { test, expect } from '@playwright/test';
import { LoginPage } from '../pages/login.page';

test.describe('P0 - 认证流程', () => {
  test('登录成功 → 跳转首页', async ({ page }) => {
    const loginPage = new LoginPage(page);
    await page.goto('/login');
    await loginPage.login('testuser', 'password123');
    await expect(page).toHaveURL('/home');
  });

  test('错误密码登录失败', async ({ page }) => {
    const loginPage = new LoginPage(page);
    await page.goto('/login');
    await loginPage.login('testuser', 'wrongpassword');
    await expect(page.locator('text=错误')).toBeVisible();
  });
});
```
---

## 六、执行记录

### 2026-05-14 测试执行记录

#### 环境信息
- Flutter Web Build: ✓ 已构建 (`flutter build web`)
- Web Server: 运行在 `localhost:3030`
- Playwright Chromium: ✓ 已配置 (`/vol4/1000/nas4/tool/chrome-linux64/chrome`)
- Browser: Chrome headless 可启动，页面标题显示 "Hermes App"

#### 问题分析
Flutter Web 应用在 headless Chromium 中使用 CanvasKit 渲染，DOM 中不包含传统 HTML input/button 元素，而是通过 Canvas 绘制 UI。Playwright 无法直接通过 CSS 选择器定位这些元素。

**观察到的日志:**
```
[debug] Installing/Activating first service worker.
[debug] Activated new service worker.
[flt-renderer] canvaskit (requested explicitly)
```

#### 当前状态
- ✅ P0 测试用例已编写完成 (`p0-auth.spec.ts`, `p0-navigation.spec.ts`, `p0-chat.spec.ts`)
- ✅ P1/P2 测试用例骨架已创建
- 🔄 测试框架搭建完成，但 Flutter Web 渲染特性导致元素定位失败
- 📋 需要在真实浏览器环境或使用 Flutter Integration Test 执行

#### 建议解决方案
1. **Flutter Integration Test**: 在真实设备/模拟器上运行 `flutter test`
2. **手动测试**: 在开发环境 `flutter run` 中验证
3. **修改 UI 层**: 为关键元素添加 `Semantics` 标签供测试使用
