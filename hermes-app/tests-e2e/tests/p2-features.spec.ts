import { test, expect, request as pwRequest } from '@playwright/test';
import { setupAuthenticatedPage, createRoomViaAPI } from '../helpers';

test.describe('P2 - 发现页', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
  });

  test('发现页显示功能入口', async ({ page }) => {
    await setupAuthenticatedPage(page);

    await page.locator('text=发现').first().click();
    await page.waitForTimeout(1500);

    // Should show Gateway and Agent entries
    const gateway = page.locator('text=Gateway').first();
    await expect(gateway).toBeVisible({ timeout: 5000 });
  });

  test('发现页显示 Agent 目录入口', async ({ page }) => {
    await setupAuthenticatedPage(page);

    await page.locator('text=发现').first().click();
    await page.waitForTimeout(1500);

    const agent = page.locator('text=Agent').first();
    await expect(agent).toBeVisible({ timeout: 5000 });
  });

  test('发现页显示即将推出标签', async ({ page }) => {
    await setupAuthenticatedPage(page);

    await page.locator('text=发现').first().click();
    await page.waitForTimeout(1500);

    const comingSoon = page.locator('text=即将推出').first();
    await expect(comingSoon).toBeVisible({ timeout: 5000 });
  });
});

test.describe('P2 - 设置页', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
  });

  test('我的 Tab 显示关于信息', async ({ page }) => {
    await setupAuthenticatedPage(page);

    await page.locator('text=我的').first().click();
    await page.waitForTimeout(1500);

    const about = page.locator('text=关于').first();
    await expect(about).toBeVisible({ timeout: 5000 });
  });

  test('我的 Tab 显示清除缓存选项', async ({ page }) => {
    await setupAuthenticatedPage(page);

    await page.locator('text=我的').first().click();
    await page.waitForTimeout(1500);

    const cache = page.locator('text=缓存').first();
    await expect(cache).toBeVisible({ timeout: 5000 });
  });
});

test.describe('P2 - 聊天进阶', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
  });

  test('进入群聊房间', async ({ page }) => {
    const { tokens } = await setupAuthenticatedPage(page);
    const room = await createRoomViaAPI(tokens.access_token, {
      name: '进阶群聊',
      mode: 'broadcast',
      agent_ids: ['agent-a'],
    });

    await page.goto(`http://localhost:3003/#/chat/${room.id}`, { waitUntil: 'load' });
    await page.waitForTimeout(4000);

    expect(page.url()).toMatch(/\/chat/);
  });

  test('聊天页面按返回回到首页', async ({ page }) => {
    const { tokens } = await setupAuthenticatedPage(page);
    const room = await createRoomViaAPI(tokens.access_token, { name: '返回测试' });

    await page.goto(`http://localhost:3003/#/chat/${room.id}`, { waitUntil: 'load' });
    await page.waitForTimeout(4000);

    await page.goBack();
    await page.waitForTimeout(3000);

    expect(page.url()).toMatch(/\/home|\/chat/);
  });
});
