import { Page, Locator, expect } from '@playwright/test';

export class ChatPage {
  readonly page: Page;
  readonly messageInput: Locator;
  readonly sendButton: Locator;
  readonly stopButton: Locator;

  constructor(page: Page) {
    this.page = page;
    // Flutter Web input for message typing
    this.messageInput = page.locator('input[placeholder*="输入"]').first();
    this.sendButton = page.locator('text=发送, [data-semantics="send"]').first();
    this.stopButton = page.locator('text=停止').first();
  }

  async sendMessage(content: string) {
    await this.messageInput.fill(content);
    await this.page.keyboard.press('Enter');
    await this.page.waitForTimeout(1000);
  }

  async expectOnChatPage() {
    expect(this.page.url()).toMatch(/\/chat/);
  }
}
