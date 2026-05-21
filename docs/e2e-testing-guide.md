# Flutter Web E2E 测试指南

## 概述

本项目使用 **Playwright** 进行 Flutter Web E2E 测试。由于 Flutter Web 使用 CanvasKit/Skia 渲染，标准 DOM 元素查找不适用，需要采用特殊策略。

## 技术方案

### 核心挑战

1. **Flutter Web 渲染特性**
   - 使用 CanvasKit (WebGL) 或 HTML 渲染器
   - UI 元素渲染在 `<canvas>` 内，不暴露标准 DOM
   - `flt-text-editing-host` 内部为空，需要特殊处理

2. **Service Worker 干扰**
   - 缓存导致测试不稳定
   - 旧版本资源被复用

### 解决方案

#### 1. 禁用 Service Worker

```typescript
// playwright.config.ts
await page.route('**/flutter_service_worker.js', route => route.abort());
```

或在测试中：

```typescript
test.beforeEach(async ({ page }) => {
  await page.route('**/flutter_service_worker.js', route => route.abort());
});
```

#### 2. 等待 Flutter 完全加载

```typescript
async function waitForFlutter(page: any) {
  // 等待 flutter-view 元素出现
  await page.waitForSelector('flutter-view', { timeout: 30000 });
  // 额外等待确保渲染完成
  await page.waitForTimeout(5000);
}
```

#### 3. 坐标点击交互

由于 DOM 元素不可见，使用坐标点击：

```typescript
// 登录表单位置（基于 1280x800 视口）
await page.mouse.click(640, 393);  // 用户名输入框
await page.keyboard.type('testuser');

await page.keyboard.press('Tab');
await page.keyboard.type('testpass123');

// 登录按钮
await page.mouse.click(640, 520);
```

#### 4. 典型登录流程

```typescript
import { test, expect } from '@playwright/test';

async function waitForFlutter(page: any) {
  await page.waitForSelector('flutter-view', { timeout: 30000 });
  await page.waitForTimeout(5000);
}

async function login(page: any) {
  // 1. 禁用 Service Worker
  await page.route('**/flutter_service_worker.js', route => route.abort());

  // 2. 导航到登录页
  await page.goto('http://localhost:3003/#/login', { waitUntil: 'load' });

  // 3. 等待 Flutter 加载
  await waitForFlutter(page);

  // 4. 填写表单
  await page.mouse.click(640, 393);  // 用户名位置
  await page.keyboard.type('testuser');

  await page.keyboard.press('Tab');   // 切换到密码框
  await page.keyboard.type('testpass123');

  // 5. 提交
  await page.mouse.click(640, 520);  // 按钮位置
  await page.waitForTimeout(3000);
}

test('登录成功', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await login(page);

  expect(page.url()).toMatch(/\/home/);
});
```

## 测试配置

### playwright.config.ts

```typescript
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests-e2e/tests',
  timeout: 60000,
  retries: 0,
  use: {
    baseURL: 'http://localhost:3003',
    headless: true,
    viewport: { width: 1280, height: 800 },
  },
  projects: [
    {
      name: 'chromium',
      use: { browserName: 'chromium' },
    },
  ],
});
```

### 启动测试

```bash
cd hermes-app/tests-e2e

# 安装依赖
npm install

# 运行所有测试
npx playwright test

# 运行单个测试文件
npx playwright test tests/p0-auth.spec.ts

# 运行单个测试用例
npx playwright test --grep "登录成功"

# 查看详细输出
npx playwright test --reporter=list

# 生成报告
npx playwright show-report
```

## 调试技巧

### 1. 截图调试

```typescript
// 在关键步骤截图
await page.screenshot({ path: '/tmp/debug.png', fullPage: true });
```

### 2. 查看 DOM 状态

```typescript
const state = await page.evaluate(() => ({
  canvasCount: document.querySelectorAll('canvas').length,
  fltGlassPane: !!document.querySelector('flt-glass-pane'),
  fltSceneHost: !!document.querySelector('flt-scene-host'),
}));
console.log(state);
```

### 3. 查找可点击元素

```typescript
// 检查元素焦点状态
const focusInfo = await page.evaluate(() => ({
  activeTag: document.activeElement?.tagName,
  activeRect: document.activeElement?.getBoundingClientRect()
}));
console.log(focusInfo);

// 点击并检查焦点
await page.mouse.click(640, 400);
await page.waitForTimeout(200);
const focused = await page.evaluate(() => document.activeElement?.tagName);
```

### 4. 检查 Flutter 加载状态

```typescript
const status = await page.evaluate(() => ({
  flutterLoaded: !!(window as any).flutter,
  canvasCount: document.querySelectorAll('canvas').length,
  fltSceneHost: !!document.querySelector('flt-scene-host'),
}));
console.log(status);
```

## 常见问题

### Q: 测试找不到 input 元素？

**A**: Flutter Web 在 canvas 内渲染，需要等待 Flutter 完全加载：

```typescript
await waitForFlutter(page);
await page.waitForTimeout(5000); // 额外等待
```

### Q: Service Worker 导致测试不稳定？

**A**: 在测试开始时禁用：

```typescript
await page.route('**/flutter_service_worker.js', route => route.abort());
```

### Q: 如何确定元素的坐标位置？

**A**: 通过调试测试逐步确定，或查看 Flutter 布局估算：
- 登录表单通常在页面垂直方向 20-40% 处
- 用户名字段约 y=393, 密码字段约 y=420, 按钮约 y=520

### Q: 输入被清除或未正确提交？

**A**: 确保焦点正确，使用 Tab 切换字段：

```typescript
await page.keyboard.press('Tab');  // 切换到下一个字段
await page.keyboard.press('Enter'); // 提交表单
```

## 测试目录结构

```
hermes-app/
├── tests-e2e/
│   ├── config/
│   │   └── playwright.config.ts
│   ├── pages/
│   │   ├── login.page.ts
│   │   ├── chat.page.ts
│   │   └── home.page.ts
│   ├── tests/
│   │   ├── p0-auth.spec.ts       # P0 - 认证流程
│   │   ├── p0-chat.spec.ts       # P0 - 聊天功能
│   │   ├── p0-navigation.spec.ts # P0 - 导航测试
│   │   ├── p1-features.spec.ts   # P1 - 进阶功能
│   │   └── p2-features.spec.ts    # P2 - 扩展功能
│   ├── package.json
│   └── node_modules/
└── integration_test/              # Flutter 集成测试
    ├── login_test.dart
    └── manual_test.dart
```

## 运行状态

| 测试类型 | 状态 | 数量 |
|----------|------|------|
| 单元测试 (flutter test) | ✅ 通过 | 35 |
| E2E 测试 (Playwright) | ✅ 通过 | 13 |
| 集成测试 (integration_test) | ⚠️ 需要配置 | - |

## 相关文档

- [Flutter Web 测试](https://docs.flutter.dev/testing/integration-tests)
- [Playwright 文档](https://playwright.dev/docs/intro)
- [Flutter Web 渲染器](https://docs.flutter.dev/development/platform-integration/web/renderers)