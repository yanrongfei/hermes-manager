import { Page, Locator, expect } from '@playwright/test';

export class HomePage {
  readonly page: Page;
  readonly chatTab: Locator;
  readonly discoverTab: Locator;
  readonly profileTab: Locator;
  readonly addButton: Locator;
  readonly searchInput: Locator;
  readonly emptyState: Locator;
  readonly roomList: Locator;

  constructor(page: Page) {
    this.page = page;
    // Bottom navigation tabs with Chinese labels
    this.chatTab = page.locator('text=对话').first();
    this.discoverTab = page.locator('text=发现').first();
    this.profileTab = page.locator('text=我的').first();
    this.addButton = page.locator('[data-semantics="add-button"], [aria-label="add"]').first();
    this.searchInput = page.locator('input[placeholder*="搜索"]').first();
    this.emptyState = page.locator('text=暂无群聊').first();
    this.roomList = page.locator('flt-glass-pane');
  }

  async switchToChat() {
    await this.chatTab.click();
    await this.page.waitForTimeout(500);
  }

  async switchToDiscover() {
    await this.discoverTab.click();
    await this.page.waitForTimeout(500);
  }

  async switchToProfile() {
    await this.profileTab.click();
    await this.page.waitForTimeout(500);
  }

  async expectOnHomePage() {
    expect(this.page.url()).toMatch(/\/home/);
  }
}
