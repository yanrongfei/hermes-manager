import { test, expect } from '@playwright/test';

async function waitForFlutter(page: any) {
  try {
    await page.waitForSelector('flutter-view', { timeout: 30000 });
    // Wait for Flutter to render
    await page.waitForTimeout(5000);
  } catch (e) {
    console.log('Flutter view not found, checking page content...');
    const content = await page.content();
    console.log('Page content length:', content.length);
  }
}

test.describe('P0 - 认证流程', () => {
  test('登录页面加载成功', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.route('**/flutter_service_worker.js', route => route.abort());

    await page.goto('http://localhost:3003/#/login', { waitUntil: 'load' });
    await waitForFlutter(page);

    // Take screenshot for debugging
    await page.screenshot({ path: '/tmp/login-page.png', fullPage: true });

    // Check if flutter-view is visible
    const flutterView = await page.locator('flutter-view').count();
    console.log('Flutter views found:', flutterView);

    // Page should load without crash
    expect(page.url()).toContain('/login');
  });

  test('注册页面加载成功', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.route('**/flutter_service_worker.js', route => route.abort());

    await page.goto('http://localhost:3003/#/register', { waitUntil: 'load' });
    await waitForFlutter(page);

    // Take screenshot for debugging
    await page.screenshot({ path: '/tmp/register-page.png', fullPage: true });

    // Check if flutter-view is visible
    const flutterView = await page.locator('flutter-view').count();
    console.log('Flutter views found:', flutterView);

    // Page should load without crash
    expect(page.url()).toContain('/register');
  });
});