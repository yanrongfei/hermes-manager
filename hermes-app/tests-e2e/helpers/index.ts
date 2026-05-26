import { Page, expect, request as pwRequest } from '@playwright/test';

const BASE_URL = 'http://localhost:3003';
const API_URL = 'http://62.234.25.205:3002';

/**
 * Wait for Flutter to fully render and enable accessibility semantics.
 * Flutter CanvasKit doesn't build the accessibility tree by default in
 * headless mode. We must click the hidden "Enable accessibility" button
 * so Playwright can find text via the accessibility tree.
 */
export async function waitForFlutter(page: Page, timeout = 30000) {
  await page.waitForSelector('flutter-view', { timeout });
  await page.waitForTimeout(4000);

  // Enable accessibility so text locators work
  await page.evaluate(() => {
    const el = document.querySelector('[aria-label="Enable accessibility"]');
    if (el) el.dispatchEvent(new MouseEvent('click', { bubbles: true }));
  });
  await page.waitForTimeout(1000);
}

/**
 * Navigate to a hash route and wait for Flutter to render.
 */
export async function goto(page: Page, path: string) {
  await page.route('**/flutter_service_worker.js', (route) => route.abort());
  await page.goto(`${BASE_URL}${path}`, { waitUntil: 'load' });
  await waitForFlutter(page);
}

/**
 * Wait for specific text to appear via accessibility tree.
 */
export async function waitForText(page: Page, text: string, timeout = 15000) {
  await page.locator(`text="${text}"`).first().waitFor({ state: 'visible', timeout });
}

/**
 * Register a user via API and return tokens + username.
 */
export async function registerViaAPI(username: string, password = 'TestPass123!') {
  const ctx = await pwRequest.newContext({ baseURL: API_URL });
  let resp = await ctx.post('/auth/register', {
    data: { username, password },
  });
  if (resp.status() !== 201 && resp.status() !== 400 && resp.status() !== 409) {
    throw new Error(`Register failed: ${resp.status()} ${await resp.text()}`);
  }

  resp = await ctx.post('/auth/login', {
    data: { username, password },
  });
  if (resp.status() !== 200) {
    throw new Error(`Login failed: ${resp.status()} ${await resp.text()}`);
  }
  const tokens = await resp.json();
  await ctx.dispose();
  return { tokens, username };
}

/**
 * Create a room via API, returns room data.
 */
export async function createRoomViaAPI(
  accessToken: string,
  options: { name?: string; mode?: string; agent_ids?: string[] } = {}
) {
  const ctx = await pwRequest.newContext({ baseURL: API_URL });
  const resp = await ctx.post('/rooms', {
    data: {
      name: options.name || 'E2E Test Room',
      mode: options.mode || 'direct',
      ...(options.agent_ids ? { agent_ids: options.agent_ids } : {}),
    },
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (resp.status() !== 201) {
    throw new Error(`Create room failed: ${resp.status()} ${await resp.text()}`);
  }
  const room = await resp.json();
  await ctx.dispose();
  return room;
}

/**
 * Inject auth tokens via addInitScript (runs before page JS).
 * shared_preferences on web uses localStorage with JSON-encoded values.
 */
export async function setupAuthenticatedPage(page: Page) {
  const timestamp = Date.now();
  const username = `e2e_${timestamp}`;
  const password = 'TestPass123!';
  const { tokens } = await registerViaAPI(username, password);

  // Use addInitScript to inject tokens BEFORE Flutter initializes
  // Values must be JSON-encoded because shared_preferences uses json.encode()
  await page.addInitScript(({ at, rt }) => {
    window.localStorage.setItem('flutter.access_token', JSON.stringify(at));
    window.localStorage.setItem('flutter.refresh_token', JSON.stringify(rt));
  }, { at: tokens.access_token, rt: tokens.refresh_token });

  await page.route('**/flutter_service_worker.js', (route) => route.abort());
  await page.goto(`${BASE_URL}/#/home`, { waitUntil: 'load' });
  await waitForFlutter(page);

  return { tokens, username, password };
}

/**
 * Reload the page while preserving auth tokens in localStorage.
 * After reload, re-enables accessibility semantics.
 */
export async function reloadPage(page: Page, tokens: { access_token: string; refresh_token: string }) {
  await page.evaluate(({ at, rt }) => {
    window.localStorage.setItem('flutter.access_token', JSON.stringify(at));
    window.localStorage.setItem('flutter.refresh_token', JSON.stringify(rt));
  }, { at: tokens.access_token, rt: tokens.refresh_token });

  await page.reload({ waitUntil: 'load' });
  await waitForFlutter(page);
}

/**
 * Fill a Flutter text field by clicking at coordinates and typing.
 */
export async function flutterType(page: Page, x: number, y: number, text: string) {
  await page.mouse.click(x, y);
  await page.waitForTimeout(300);
  await page.keyboard.press('Control+a');
  await page.keyboard.type(text, { delay: 50 });
}
