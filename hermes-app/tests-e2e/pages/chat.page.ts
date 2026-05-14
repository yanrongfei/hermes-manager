import { Page, Locator, expect } from '@playwright/test';

export class ChatPage {
  readonly page: Page;
  readonly messageInput: Locator;
  readonly sendButton: Locator;
  readonly stopButton: Locator;
  readonly runningAgentsBar: Locator;
  readonly mentionPicker: Locator;

  constructor(page: Page) {
    this.page = page;
    this.messageInput = page.locator('input[type="text"], input[placeholder*="输入"]').first();
    this.sendButton = page.locator('button:has-icon(Icons.send), button:has-text("send")').first();
    this.stopButton = page.locator('button:has-text("停止")').first();
    this.runningAgentsBar = page.locator('text=正在思考').first();
    this.mentionPicker = page.locator('text=选择 Agent').first();
  }

  async sendMessage(content: string) {
    await this.messageInput.fill(content);
    await this.sendButton.click();
  }

  async expectMessageVisible(content: string) {
    await expect(page.locator(`text=${content}`).first()).toBeVisible();
  }

  async stopAgents() {
    await this.stopButton.click();
  }
}