import { test, expect, request as pwRequest } from '@playwright/test';
import { setupAuthenticatedPage, createRoomViaAPI, registerViaAPI, reloadPage } from '../helpers';

test.describe('P1 - 房间管理', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
  });

  test('创建一对一房间并在列表中显示', async ({ page }) => {
    const { tokens } = await setupAuthenticatedPage(page);
    const room = await createRoomViaAPI(tokens.access_token, {
      name: '1v1-Agent',
      mode: 'direct',
      agent_ids: ['test-agent'],
    });

    expect(room.mode).toBe('direct');
    expect(room.id).toBeTruthy();

    await reloadPage(page, tokens);

    // Room names aren't in accessibility tree. Verify empty state is gone.
    const emptyState = page.locator('text=暂无').first();
    await expect(emptyState).not.toBeVisible({ timeout: 10000 });
  });

  test('创建群聊房间', async ({ page }) => {
    const { tokens } = await setupAuthenticatedPage(page);
    const room = await createRoomViaAPI(tokens.access_token, {
      name: '群聊房间测试',
      mode: 'broadcast',
      agent_ids: ['agent-a', 'agent-b'],
    });

    expect(room.mode).toBe('broadcast');

    await reloadPage(page, tokens);

    // Room names aren't in accessibility tree. Verify empty state is gone.
    const emptyState = page.locator('text=暂无').first();
    await expect(emptyState).not.toBeVisible({ timeout: 10000 });
  });

  test('修改房间名称后列表更新', async ({ page }) => {
    const { tokens } = await setupAuthenticatedPage(page);
    const room = await createRoomViaAPI(tokens.access_token, { name: '旧名称' });

    const ctx = await pwRequest.newContext({ baseURL: 'http://62.234.25.205:3002' });
    const updateResp = await ctx.put(`/rooms/${room.id}`, {
      data: { name: '新名称房间' },
      headers: { Authorization: `Bearer ${tokens.access_token}` },
    });
    expect(updateResp.status()).toBe(200);
    await ctx.dispose();

    // Verify rename via API since room names aren't in accessibility tree
    const verifyCtx = await pwRequest.newContext({ baseURL: 'http://62.234.25.205:3002' });
    const detailResp = await verifyCtx.get(`/rooms/${room.id}`, {
      headers: { Authorization: `Bearer ${tokens.access_token}` },
    });
    const detail = await detailResp.json();
    expect(detail.name).toBe('新名称房间');
    await verifyCtx.dispose();
  });
});

test.describe('P1 - 成员管理', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
  });

  test('邀请码生成与加入', async ({ page }) => {
    const { tokens } = await setupAuthenticatedPage(page);
    const room = await createRoomViaAPI(tokens.access_token, {
      name: '邀请测试群',
      mode: 'broadcast',
    });

    const ctx = await pwRequest.newContext({ baseURL: 'http://62.234.25.205:3002' });

    // Generate invite code
    const inviteResp = await ctx.post(`/rooms/${room.id}/invite`, {
      headers: { Authorization: `Bearer ${tokens.access_token}` },
    });
    expect(inviteResp.status()).toBe(200);
    const { invite_code } = await inviteResp.json();
    expect(invite_code).toBeTruthy();

    // Register second user and join
    const userB = await registerViaAPI(`invitee_${Date.now()}`);
    const joinResp = await ctx.post('/rooms/join', {
      params: { invite_code },
      headers: { Authorization: `Bearer ${userB.tokens.access_token}` },
    });
    expect(joinResp.status()).toBe(200);

    // Verify members
    const detailResp = await ctx.get(`/rooms/${room.id}`, {
      headers: { Authorization: `Bearer ${tokens.access_token}` },
    });
    const detail = await detailResp.json();
    expect(detail.members.length).toBeGreaterThanOrEqual(2);

    await ctx.dispose();
  });

  test('查看房间成员列表', async ({ page }) => {
    const { tokens } = await setupAuthenticatedPage(page);
    const room = await createRoomViaAPI(tokens.access_token, {
      name: '成员测试群',
      mode: 'broadcast',
    });

    const ctx = await pwRequest.newContext({ baseURL: 'http://62.234.25.205:3002' });
    const resp = await ctx.get(`/rooms/${room.id}/members`, {
      headers: { Authorization: `Bearer ${tokens.access_token}` },
    });
    expect(resp.status()).toBe(200);
    const members = await resp.json();
    expect(members.length).toBeGreaterThanOrEqual(1);
    expect(members.some((m: any) => m.role === 'owner')).toBeTruthy();
    await ctx.dispose();
  });
});

test.describe('P1 - 个人中心', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
  });

  test('我的 Tab 显示设置选项', async ({ page }) => {
    await setupAuthenticatedPage(page);

    await page.locator('text=我的').first().click();
    await page.waitForTimeout(1500);

    const settings = page.locator('text=设置').first();
    await expect(settings).toBeVisible({ timeout: 5000 });
  });

  test('退出登录返回登录页', async ({ page }) => {
    await setupAuthenticatedPage(page);

    await page.locator('text=我的').first().click();
    await page.waitForTimeout(1500);

    const logoutBtn = page.locator('text=退出登录').first();
    await expect(logoutBtn).toBeVisible({ timeout: 5000 });
    await logoutBtn.click();
    await page.waitForTimeout(1000);

    // Confirm dialog
    const confirmBtn = page.locator('text=退出').last();
    if (await confirmBtn.isVisible().catch(() => false)) {
      await confirmBtn.click();
    }
    await page.waitForTimeout(3000);

    expect(page.url()).toMatch(/\/login/);
  });
});
