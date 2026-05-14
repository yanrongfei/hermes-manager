import { Page, Locator, expect } from '@playwright/test';

export class LoginPage {
  readonly page: Page;
  readonly usernameInput: Locator;
  readonly passwordInput: Locator;
  readonly loginButton: Locator;
  readonly registerLink: Locator;
  readonly errorMessage: Locator;

  constructor(page: Page) {
    this.page = page;
    this.usernameInput = page.locator('input[name="username"], input[type="text"]').first();
    this.passwordInput = page.locator('input[type="password"]').first();
    this.loginButton = page.locator('button[type="submit"], button:has-text("Login")').first();
    this.registerLink = page.locator('button:has-text("Register"), a:has-text("Register")').first();
    this.errorMessage = page.locator('text=错误, text=Invalid, text=Failed').first();
  }

  async goto() {
    await this.page.goto('/login');
  }

  async login(username: string, password: string) {
    await this.usernameInput.fill(username);
    await this.passwordInput.fill(password);
    await this.loginButton.click();
  }

  async expectRedirectToHome() {
    await expect(this.page).toHaveURL(/\/home/);
  }

  async expectLoginButton() {
    await expect(this.loginButton).toBeVisible();
  }
}