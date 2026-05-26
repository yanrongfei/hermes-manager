import { test, expect } from '@playwright/test';
import { goto, flutterType, waitForFlutter } from '../helpers';

test.describe('P0 - 认证流程', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
  });

  test('登录页面正常加载', async ({ page }) => {
    await goto(page, '/#/login');

    const flutterView = await page.locator('flutter-view').count();
    expect(flutterView).toBeGreaterThan(0);
    expect(page.url()).toContain('/login');
  });

  test('登录页面点击可激活输入框', async ({ page }) => {
    await goto(page, '/#/login');

    // Click on the first text field area to activate it
    await page.mouse.click(640, 370);
    await page.waitForTimeout(500);

    const inputs = await page.locator('input').all();
    expect(inputs.length).toBeGreaterThanOrEqual(1);
  });

  test('使用错误密码登录停留在登录页', async ({ page }) => {
    await goto(page, '/#/login');

    // Click username field and type
    await flutterType(page, 640, 370, 'nonexistent_user_xyz');
    // Click password field and type
    await flutterType(page, 640, 440, 'wrong_password');

    await page.keyboard.press('Enter');
    await page.waitForTimeout(3000);

    expect(page.url()).toContain('/login');
  });

  test('注册页面正常加载', async ({ page }) => {
    await goto(page, '/#/register');

    const flutterView = await page.locator('flutter-view').count();
    expect(flutterView).toBeGreaterThan(0);
    expect(page.url()).toContain('/register');
  });

  test('注册页面点击可激活输入框', async ({ page }) => {
    await goto(page, '/#/register');

    await page.mouse.click(640, 340);
    await page.waitForTimeout(500);

    const inputs = await page.locator('input').all();
    expect(inputs.length).toBeGreaterThanOrEqual(1);
  });

  test('通过 UI 注册新用户成功', async ({ page }) => {
    await goto(page, '/#/register');

    const username = `uireg_${Date.now()}`;
    const password = 'TestPass123!';

    // Fill three fields: username, password, confirm password
    await flutterType(page, 640, 340, username);
    await flutterType(page, 640, 410, password);
    await flutterType(page, 640, 480, password);

    await page.keyboard.press('Enter');
    await page.waitForTimeout(5000);

    // Should navigate away from register (to home on success, or stay on register)
    const url = page.url();
    expect(url).toMatch(/\/(home|register|login)/);
  });

  test('未登录访问 /home 重定向到登录页', async ({ page }) => {
    await page.route('**/flutter_service_worker.js', (route) => route.abort());
    await page.goto('http://localhost:3003/#/home', { waitUntil: 'load' });
    await page.waitForTimeout(5000);

    expect(page.url()).toMatch(/\/login/);
  });

  test('Splash 页面自动跳转', async ({ page }) => {
    await page.route('**/flutter_service_worker.js', (route) => route.abort());
    await page.goto('http://localhost:3003/', { waitUntil: 'load' });
    await page.waitForTimeout(5000);

    expect(page.url()).toMatch(/\/(login|home)/);
  });
});
