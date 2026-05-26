import { test, expect } from '@playwright/test';
import { setupAuthenticatedPage, waitForText } from '../helpers';

test.describe('P0 - 导航测试', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await setupAuthenticatedPage(page);
  });

  test('首页包含三个底部 Tab', async ({ page }) => {
    // Use locator-based checks (accessibility tree), not page.content()
    const chatTab = page.locator('text=对话').first();
    const discoverTab = page.locator('text=发现').first();
    const profileTab = page.locator('text=我的').first();

    await expect(chatTab).toBeVisible({ timeout: 5000 });
    await expect(discoverTab).toBeVisible({ timeout: 5000 });
    await expect(profileTab).toBeVisible({ timeout: 5000 });
  });

  test('默认显示对话 Tab', async ({ page }) => {
    expect(page.url()).toMatch(/\/home/);

    // Chat tab content: "Hermes" header or search bar
    const hermes = page.locator('text=Hermes').first();
    await expect(hermes).toBeVisible({ timeout: 5000 });
  });

  test('切换到发现 Tab 显示功能列表', async ({ page }) => {
    await page.locator('text=发现').first().click();
    await page.waitForTimeout(1500);

    // Should show discover content
    const gateway = page.locator('text=Gateway').first();
    await expect(gateway).toBeVisible({ timeout: 5000 });
  });

  test('切换到我的 Tab 显示设置', async ({ page }) => {
    await page.locator('text=我的').first().click();
    await page.waitForTimeout(1500);

    // Should show settings
    const settings = page.locator('text=设置').first();
    await expect(settings).toBeVisible({ timeout: 5000 });
  });

  test('Tab 之间来回切换', async ({ page }) => {
    // Switch tabs sequentially
    await page.locator('text=发现').first().click();
    await page.waitForTimeout(800);
    await page.locator('text=我的').first().click();
    await page.waitForTimeout(800);
    await page.locator('text=对话').first().click();
    await page.waitForTimeout(800);

    // Should still be on home page
    expect(page.url()).toMatch(/\/home/);
  });
});
