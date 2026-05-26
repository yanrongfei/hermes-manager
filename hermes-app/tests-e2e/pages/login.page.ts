import { Page, Locator, expect } from '@playwright/test';

export class LoginPage {
  readonly page: Page;
  readonly usernameInput: Locator;
  readonly passwordInput: Locator;
  readonly loginButton: Locator;
  readonly registerLink: Locator;

  constructor(page: Page) {
    this.page = page;
    // Flutter Web renders <input> elements for text fields
    this.usernameInput = page.locator('input').first();
    this.passwordInput = page.locator('input[type="password"], input').nth(1);
    this.loginButton = page.locator('button, [role="button"]').first();
    this.registerLink = page.locator('text=没有账号').first();
  }

  async goto() {
    await this.page.route('**/flutter_service_worker.js', (route) => route.abort());
    await this.page.goto('http://localhost:3003/#/login', { waitUntil: 'load' });
    await this.page.waitForSelector('flutter-view', { timeout: 30000 });
    await this.page.waitForTimeout(3000);
  }

  async login(username: string, password: string) {
    const inputs = await this.page.locator('input').all();
    if (inputs.length >= 2) {
      await inputs[0].fill(username);
      await inputs[1].fill(password);
    }
    await this.page.keyboard.press('Enter');
    await this.page.waitForTimeout(3000);
  }

  async expectOnLoginPage() {
    await expect(this.page).toHaveURL(/\/login/);
  }

  async expectRedirectToHome() {
    await this.page.waitForURL(/\/home/, { timeout: 10000 }).catch(() => {});
    expect(this.page.url()).toMatch(/\/home/);
  }
}
