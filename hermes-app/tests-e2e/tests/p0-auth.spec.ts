import { test, expect } from '@playwright/test';
import { LoginPage } from '../pages/login.page';

test.describe('P0 - 认证流程', () => {
  let loginPage: LoginPage;

  test.beforeEach(async ({ page }) => {
    loginPage = new LoginPage(page);
  });

  test('登录成功 → 跳转首页', async ({ page }) => {
    await loginPage.goto();
    await loginPage.login('testuser', 'password123');
    await expect(page).toHaveURL(/\/home/);
  });

  test('错误密码登录失败', async ({ page }) => {
    await loginPage.goto();
    await loginPage.login('testuser', 'wrongpassword');
    // Error message should appear or stay on login page
    await expect(loginPage.loginButton).toBeVisible();
  });

  test('未注册用户登录', async ({ page }) => {
    await loginPage.goto();
    await loginPage.login('nonexistent', 'anypassword');
    // Should show error or stay on login page
    await expect(loginPage.loginButton).toBeVisible();
  });
});