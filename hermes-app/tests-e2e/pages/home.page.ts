import { Page, Locator, expect } from '@playwright/test';

export class HomePage {
  readonly page: Page;
  readonly chatTab: Locator;
  readonly discoverTab: Locator;
  readonly profileTab: Locator;

  constructor(page: Page) {
    this.page = page;
    this.chatTab = page.locator('text=对话').first();
    this.discoverTab = page.locator('text=发现').first();
    this.profileTab = page.locator('text=我的').first();
  }

  async switchToChat() {
    await this.chatTab.click();
  }

  async switchToDiscover() {
    await this.discoverTab.click();
  }

  async switchToProfile() {
    await this.profileTab.click();
  }

  async expectTabsVisible() {
    await expect(this.chatTab).toBeVisible();
    await expect(this.discoverTab).toBeVisible();
    await expect(this.profileTab).toBeVisible();
  }
}