import { test, expect } from '@playwright/test';
import { HomePage } from '../pages/home.page';

test.describe('P0 - 导航测试', () => {
  let homePage: HomePage;

  test.beforeEach(async ({ page }) => {
    homePage = new HomePage(page);
  });

  test('Tab 切换', async ({ page }) => {
    // Assume already logged in at /home
    await page.goto('/home');
    await homePage.expectTabsVisible();

    // Switch to discover tab
    await homePage.switchToDiscover();
    await expect(page.locator('text=发现')).toBeVisible();

    // Switch to profile tab
    await homePage.switchToProfile();
    await expect(page.locator('text=我的')).toBeVisible();

    // Switch back to chat tab
    await homePage.switchToChat();
    await expect(page.locator('text=对话')).toBeVisible();
  });
});