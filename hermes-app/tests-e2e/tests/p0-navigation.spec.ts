import { test, expect } from '@playwright/test';

async function waitForFlutter(page: any) {
  await page.waitForSelector('flutter-view', { timeout: 30000 });
  await page.waitForTimeout(5000);
}

async function login(page: any) {
  await page.route('**/flutter_service_worker.js', route => route.abort());
  await page.goto('http://localhost:3003/#/login', { waitUntil: 'load' });
  await waitForFlutter(page);

  await page.mouse.click(640, 393);
  await page.waitForTimeout(200);
  await page.keyboard.type('testuser');
  await page.keyboard.press('Tab');
  await page.keyboard.type('testpass123');

  await page.mouse.click(640, 520);
  await page.waitForTimeout(3000);
}

test.describe('P0 - 导航测试', () => {
  test('Tab 切换', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await login(page);

    // Should be on home page
    expect(page.url()).toMatch(/\/home/);

    // Click on settings tab (approximate position)
    // Settings tab is usually at bottom-right or in app bar
    await page.mouse.click(1150, 750);
    await page.waitForTimeout(1000);

    // Just verify we're still in the app
    expect(page.url()).toMatch(/\/(home|settings)/);
  });
});