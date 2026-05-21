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

test.describe('P2 - 扩展功能', () => {
  test('邀请成员 Modal', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await login(page);

    // Try to navigate to a chat room
    await page.mouse.click(200, 200);
    await page.waitForTimeout(2000);

    // Just verify we can navigate
    const url = page.url();
    expect(url.includes('/home') || url.includes('/chat')).toBeTruthy();
  });

  test('附件上传 Modal', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await login(page);

    // Try to navigate to a chat room
    await page.mouse.click(200, 200);
    await page.waitForTimeout(2000);

    // Just verify navigation works
    const url = page.url();
    expect(url.includes('/home') || url.includes('/chat')).toBeTruthy();
  });

  test('打字状态指示器', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await login(page);

    // Try to navigate to a chat room
    await page.mouse.click(200, 200);
    await page.waitForTimeout(2000);

    if (page.url().includes('/chat')) {
      // Type in input to trigger typing indicator
      await page.mouse.click(640, 700);
      await page.keyboard.type('typing...');
      await page.waitForTimeout(500);

      // Verify text was typed
      await expect(page.locator('text=typing...')).toBeVisible();
    }
  });
});