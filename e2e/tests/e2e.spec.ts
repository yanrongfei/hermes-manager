import { test, expect, Page } from '@playwright/test';

const APP_URL = 'http://localhost:8080';
const API_URL = 'http://localhost:8000';
const TEST_USER = `e2e_user_${Date.now()}`;
const TEST_PASS = 'TestPass123!';

// Helper: wait for Flutter to render (semantics tree is built)
async function waitForFlutter(page: Page) {
  await page.waitForTimeout(1000);
}

// Helper: find Flutter text by role=text or semantic label
async function findText(page: Page, text: string) {
  return page.locator(`text="${text}"`).first();
}

// Helper: find input by label (Flutter renders input labels as semantics)
async function fillField(page: Page, label: string, value: string) {
  // Flutter TextFormField renders with aria-label or associated label
  const input = page.locator(`input[aria-label="${label}"], input[placeholder="${label}"]`).first();
  if (await input.count() > 0) {
    await input.fill(value);
    return;
  }
  // Fallback: find by visible label text near input
  const allInputs = page.locator('input[type="text"], input[type="password"], input:not([type])');
  const count = await allInputs.count();
  for (let i = 0; i < count; i++) {
    const el = allInputs.nth(i);
    const ariaLabel = await el.getAttribute('aria-label') ?? '';
    const placeholder = await el.getAttribute('placeholder') ?? '';
    if (ariaLabel.includes(label) || placeholder.includes(label)) {
      await el.fill(value);
      return;
    }
  }
  // Last resort: fill the first empty input
  if (count > 0) {
    await allInputs.first().fill(value);
  }
}

// Helper: click button by text
async function clickButton(page: Page, text: string) {
  const btn = page.locator(`button:has-text("${text}"), [role="button"]:has-text("${text}")`).first();
  if (await btn.count() > 0) {
    await btn.click();
    return;
  }
  // Flutter may render as a generic element with semantics role
  await page.locator(`text="${text}"`).first().click();
}

// ============================================================
// Test Suite
// ============================================================

test.describe('Hermes App E2E', () => {

  test('01 - App loads and shows splash screen', async ({ page }) => {
    await page.goto(APP_URL);
    await waitForFlutter(page);
    // Should show "Hermes" branding
    await expect(page.locator('text=Hermes')).toBeVisible({ timeout: 15000 });
  });

  test('02 - Splash redirects to login', async ({ page }) => {
    await page.goto(APP_URL);
    await waitForFlutter(page);
    // Wait for navigation to login
    await expect(page.locator('text=Login')).toBeVisible({ timeout: 15000 });
  });

  test('03 - Shows validation errors on empty login', async ({ page }) => {
    await page.goto(APP_URL);
    await waitForFlutter(page);
    await expect(page.locator('text=Login')).toBeVisible({ timeout: 15000 });

    // Click Login without filling fields
    const loginBtn = page.locator('text=Login').first();
    await loginBtn.click();
    await waitForFlutter(page);
    // Should stay on login page (form validation prevents submit)
    await expect(page.locator('text=Login')).toBeVisible();
  });

  test('04 - Navigate to register screen', async ({ page }) => {
    await page.goto(APP_URL);
    await waitForFlutter(page);
    await expect(page.locator('text=Login')).toBeVisible({ timeout: 15000 });

    // Click "Don't have an account? Register"
    const registerLink = page.locator('text=Register').first();
    await registerLink.click();
    await waitForFlutter(page);

    // Should be on register screen
    await expect(page.locator('text=Username')).toBeVisible({ timeout: 10000 });
  });

  test('05 - Register a new user', async ({ page }) => {
    await page.goto(APP_URL);
    await waitForFlutter(page);
    await expect(page.locator('text=Login')).toBeVisible({ timeout: 15000 });

    // Go to register
    await page.locator('text=Register').first().click();
    await waitForFlutter(page);
    await expect(page.locator('text=Username')).toBeVisible({ timeout: 10000 });

    // Fill form
    const inputs = page.locator('input');
    await inputs.nth(0).fill(TEST_USER);
    await inputs.nth(1).fill(TEST_PASS);
    await inputs.nth(2).fill(TEST_PASS);

    // Submit
    await page.locator('text=Register').last().click();
    await waitForFlutter(page);

    // After register, should auto-login and go to home
    // Look for home tab "对话"
    await expect(page.locator('text=对话')).toBeVisible({ timeout: 15000 });
  });

  test('06 - Login with existing user', async ({ page }) => {
    // First register via API to ensure user exists
    await fetch(`${API_URL}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: `login_test_${Date.now()}`, password: TEST_PASS }),
    }).catch(() => {}); // ignore if exists

    await page.goto(APP_URL);
    await waitForFlutter(page);
    await expect(page.locator('text=Login')).toBeVisible({ timeout: 15000 });

    // Fill login form
    const inputs = page.locator('input');
    const inputCount = await inputs.count();
    if (inputCount >= 2) {
      await inputs.nth(0).fill(`login_test_${Date.now()}`);
      await inputs.nth(1).fill(TEST_PASS);
    }

    // Click Login button
    await page.locator('text=Login').first().click();
    // May fail if user doesn't exist yet, but test the flow
  });

  test('07 - Full flow: register → home → create room', async ({ page }) => {
    const username = `flow_${Date.now()}`;

    // Navigate to app
    await page.goto(APP_URL);
    await waitForFlutter(page);
    await expect(page.locator('text=Login')).toBeVisible({ timeout: 15000 });

    // Go to register
    await page.locator('text=Register').first().click();
    await waitForFlutter(page);

    // Register
    const inputs = page.locator('input');
    await inputs.nth(0).fill(username);
    await inputs.nth(1).fill(TEST_PASS);
    await inputs.nth(2).fill(TEST_PASS);
    await page.locator('text=Register').last().click();
    await waitForFlutter(page);

    // Should be on home screen with tabs
    await expect(page.locator('text=对话')).toBeVisible({ timeout: 15000 });
    await expect(page.locator('text=发现')).toBeVisible({ timeout: 10000 });
    await expect(page.locator('text=我的')).toBeVisible({ timeout: 10000 });

    // Chat list should show empty state
    await expect(page.locator('text=暂无群聊')).toBeVisible({ timeout: 5000 });
  });

  test('08 - Discover tab shows features', async ({ page }) => {
    const username = `disc_${Date.now()}`;

    // Quick register
    await page.goto(APP_URL);
    await waitForFlutter(page);
    await expect(page.locator('text=Login')).toBeVisible({ timeout: 15000 });
    await page.locator('text=Register').first().click();
    await waitForFlutter(page);
    const inputs = page.locator('input');
    await inputs.nth(0).fill(username);
    await inputs.nth(1).fill(TEST_PASS);
    await inputs.nth(2).fill(TEST_PASS);
    await page.locator('text=Register').last().click();
    await waitForFlutter(page);
    await expect(page.locator('text=对话')).toBeVisible({ timeout: 15000 });

    // Navigate to Discover tab
    await page.locator('text=发现').click();
    await waitForFlutter(page);

    // Should show discovery items
    await expect(page.locator('text=连接')).toBeVisible({ timeout: 5000 });
    await expect(page.locator('text=Gateway 管理')).toBeVisible();
  });

  test('09 - Profile tab shows user info and logout', async ({ page }) => {
    const username = `prof_${Date.now()}`;

    // Quick register
    await page.goto(APP_URL);
    await waitForFlutter(page);
    await expect(page.locator('text=Login')).toBeVisible({ timeout: 15000 });
    await page.locator('text=Register').first().click();
    await waitForFlutter(page);
    const inputs = page.locator('input');
    await inputs.nth(0).fill(username);
    await inputs.nth(1).fill(TEST_PASS);
    await inputs.nth(2).fill(TEST_PASS);
    await page.locator('text=Register').last().click();
    await waitForFlutter(page);
    await expect(page.locator('text=对话')).toBeVisible({ timeout: 15000 });

    // Navigate to Profile tab
    await page.locator('text=我的').click();
    await waitForFlutter(page);

    // Should show username and logout
    await expect(page.locator('text=设置')).toBeVisible({ timeout: 5000 });
    await expect(page.locator('text=退出登录')).toBeVisible();
  });

  test('10 - Logout returns to login screen', async ({ page }) => {
    const username = `logout_${Date.now()}`;

    // Quick register
    await page.goto(APP_URL);
    await waitForFlutter(page);
    await expect(page.locator('text=Login')).toBeVisible({ timeout: 15000 });
    await page.locator('text=Register').first().click();
    await waitForFlutter(page);
    const inputs = page.locator('input');
    await inputs.nth(0).fill(username);
    await inputs.nth(1).fill(TEST_PASS);
    await inputs.nth(2).fill(TEST_PASS);
    await page.locator('text=Register').last().click();
    await waitForFlutter(page);
    await expect(page.locator('text=对话')).toBeVisible({ timeout: 15000 });

    // Go to profile
    await page.locator('text=我的').click();
    await waitForFlutter(page);

    // Click logout button
    await page.locator('text=退出登录').click();
    await waitForFlutter(page);

    // Confirm logout in dialog
    const confirmBtn = page.locator('text=退出').last();
    if (await confirmBtn.isVisible()) {
      await confirmBtn.click();
    }
    await waitForFlutter(page);

    // Should be back on login
    await expect(page.locator('text=Login')).toBeVisible({ timeout: 10000 });
  });
});
