import { test, expect } from '@playwright/test';

test('Debug - find elements by text', async ({ page }) => {
  await page.goto('http://localhost:3030/#/login');
  await page.waitForTimeout(5000);

  // Find all text elements
  const loginButton = await page.getByText('Login').first();
  const isLoginVisible = await loginButton.isVisible().catch(() => false);
  console.log('Login button visible:', isLoginVisible);

  const usernameLabel = await page.getByText('Username').first();
  const isUsernameVisible = await usernameLabel.isVisible().catch(() => false);
  console.log('Username label visible:', isUsernameVisible);

  const passwordLabel = await page.getByText('Password').first();
  const isPasswordVisible = await passwordLabel.isVisible().catch(() => false);
  console.log('Password label visible:', isPasswordVisible);

  // Find inputs by placeholder
  const inputs = await page.locator('input').all();
  console.log('Total inputs found:', inputs.length);

  await page.screenshot({ path: '/tmp/debug-login2.png' });
});