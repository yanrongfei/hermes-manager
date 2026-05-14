import { test, expect } from '@playwright/test';

test.describe('P1 - 聊天进阶功能', () => {
  test('@mention Agent 选择', async ({ page }) => {
    await page.goto('/chat/1');
    const input = page.locator('input[type="text"]').first();
    await input.fill('@');
    // Mention picker should appear
    await expect(page.locator('text=选择 Agent')).toBeVisible();
  });

  test('停止 Agent 响应', async ({ page }) => {
    await page.goto('/chat/1');
    // If running agents bar appears, stop button should be visible
    const stopButton = page.locator('button:has-text("停止")');
    if (await stopButton.isVisible()) {
      await stopButton.click();
    }
  });
});

test.describe('P1 - 注册流程', () => {
  test('注册新用户', async ({ page }) => {
    await page.goto('/login');
    await page.locator('button:has-text("Register")').click();
    await expect(page).toHaveURL(/\/register/);
  });
});

test.describe('P1 - 状态管理', () => {
  test('未登录重定向', async ({ page }) => {
    // Clear storage and try to access home
    await page.goto('/home');
    // Should redirect to login
    await expect(page).toHaveURL(/\/login/);
  });
});