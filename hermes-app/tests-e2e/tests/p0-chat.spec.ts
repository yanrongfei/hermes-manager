import { test, expect } from '@playwright/test';
import { ChatPage } from '../pages/chat.page';

test.describe('P0 - 聊天功能', () => {
  let chatPage: ChatPage;

  test.beforeEach(async ({ page }) => {
    chatPage = new ChatPage(page);
  });

  test('发送消息', async ({ page }) => {
    await page.goto('/chat/1');
    await chatPage.sendMessage('Hello, Hermes!');
    // Verify message appears in the list
    await expect(page.locator('text=Hello, Hermes!')).toBeVisible();
  });

  test('消息列表自动滚动', async ({ page }) => {
    await page.goto('/chat/1');
    // Send multiple messages
    for (let i = 1; i <= 5; i++) {
      await chatPage.sendMessage(`Message ${i}`);
    }
    // Verify last message is visible
    await expect(page.locator('text=Message 5')).toBeVisible();
  });
});