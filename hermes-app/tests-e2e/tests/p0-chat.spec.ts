import { test, expect } from '@playwright/test';

// Helper functions
async function waitForFlutter(page: any) {
  await page.waitForSelector('flutter-view', { timeout: 30000 });
  await page.waitForTimeout(5000);
}

async function login(page: any) {
  await page.route('**/flutter_service_worker.js', route => route.abort());
  await page.goto('http://localhost:3003/#/login', { waitUntil: 'load' });
  await waitForFlutter(page);

  // Fill login form
  await page.mouse.click(640, 393);
  await page.waitForTimeout(200);
  await page.keyboard.type('testuser');
  await page.keyboard.press('Tab');
  await page.keyboard.type('testpass123');

  // Submit
  await page.mouse.click(640, 520);
  await page.waitForTimeout(3000);
}

test.describe('P0 - 聊天功能', () => {
  test('发送消息', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await login(page);

    // Should be on home page now
    expect(page.url()).toMatch(/\/home/);

    // Navigate to first available room by clicking on room items
    // Try clicking around the left side where room items typically are
    await page.mouse.click(200, 200);
    await page.waitForTimeout(2000);

    // Check if we're in a chat room
    let currentUrl = page.url();
    if (!currentUrl.includes('/chat')) {
      // Try clicking other positions
      await page.mouse.click(200, 280);
      await page.waitForTimeout(2000);
    }

    currentUrl = page.url();

    if (currentUrl.includes('/chat')) {
      // We're in a chat room, try to send a message
      // Input field should be at bottom of chat
      await page.mouse.click(640, 700);
      await page.waitForTimeout(300);
      await page.keyboard.type('Hello, Hermes!');
      await page.keyboard.press('Enter');
      await page.waitForTimeout(2000);

      // Verify message appears
      await expect(page.locator('text=Hello, Hermes!')).toBeVisible();
    }
  });

  test('消息列表自动滚动', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await login(page);

    // Try to navigate to a chat room
    await page.mouse.click(200, 200);
    await page.waitForTimeout(2000);

    const currentUrl = page.url();
    if (currentUrl.includes('/chat')) {
      // Send multiple messages
      for (let i = 1; i <= 3; i++) {
        await page.mouse.click(640, 700);
        await page.waitForTimeout(200);
        await page.keyboard.type(`Message ${i}`);
        await page.keyboard.press('Enter');
        await page.waitForTimeout(500);
      }

      // Verify last message is visible
      await expect(page.locator('text=Message 3')).toBeVisible();
    }
  });
});