import { test, expect } from '@playwright/test';

async function waitForFlutter(page: any) {
  await page.waitForSelector('flutter-view', { timeout: 30000 });
  await page.waitForTimeout(5000);
}

async function fillLoginForm(page: any) {
  // Click username field (first input)
  await page.mouse.click(640, 393);
  await page.waitForTimeout(300);
  await page.keyboard.type('testuser');

  // Press Tab to move to password field
  await page.keyboard.press('Tab');
  await page.waitForTimeout(200);
  await page.keyboard.type('testpass123');
}

test.describe('P0 - 认证流程', () => {
  test('登录成功 → 跳转首页', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.route('**/flutter_service_worker.js', route => route.abort());

    await page.goto('http://localhost:3003/#/login', { waitUntil: 'load' });
    await waitForFlutter(page);

    await fillLoginForm(page);

    // Take screenshot before submit
    await page.screenshot({ path: '/tmp/form-state.png', fullPage: true });

    // Try clicking the button directly (below password field)
    // Password field ends around y=417, button should be around y=450-500
    await page.mouse.click(640, 460);
    await page.waitForTimeout(1000);

    // Check URL
    let url = page.url();
    console.log('After button click:', url);

    // If still on login, try Enter key
    if (url.includes('/login')) {
      await page.keyboard.press('Enter');
      await page.waitForTimeout(3000);
      url = page.url();
      console.log('After Enter:', url);
    }

    // If still on login, try clicking the second input's submit button
    if (url.includes('/login')) {
      // Find and click button more precisely
      await page.evaluate(() => {
        const inputs = document.querySelectorAll('input');
        if (inputs.length >= 2) {
          const secondInput = inputs[1] as HTMLInputElement;
          console.log('Password field value:', secondInput.value);
        }
      });

      // Click somewhere that might be the button area
      await page.mouse.click(640, 520);
      await page.waitForTimeout(2000);
      url = page.url();
      console.log('After third click:', url);
    }

    await page.screenshot({ path: '/tmp/final-state.png', fullPage: true });

    expect(url).toMatch(/\/home/);
  });

  test('错误密码登录失败', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.route('**/flutter_service_worker.js', route => route.abort());

    await page.goto('http://localhost:3003/#/login', { waitUntil: 'load' });
    await waitForFlutter(page);

    await fillLoginForm(page);

    // Use wrong password (this test passes because wrong password keeps us on login page)
    // Replace password with wrong one
    await page.keyboard.press('Control+a');
    await page.keyboard.type('wrongpassword');

    await page.keyboard.press('Enter');
    await page.waitForTimeout(3000);

    const url = page.url();
    expect(url).toMatch(/\/login/);
  });

  test('未注册用户登录', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.route('**/flutter_service_worker.js', route => route.abort());

    await page.goto('http://localhost:3003/#/login', { waitUntil: 'load' });
    await waitForFlutter(page);

    await fillLoginForm(page);

    // Replace username with unregistered user
    await page.mouse.click(640, 393);
    await page.keyboard.press('Control+a');
    await page.keyboard.type('nonexistentuser99999');

    await page.keyboard.press('Enter');
    await page.waitForTimeout(3000);

    const url = page.url();
    expect(url).toMatch(/\/login/);
  });
});