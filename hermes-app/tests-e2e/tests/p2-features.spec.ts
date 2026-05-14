import { test, expect } from '@playwright/test';

test.describe('P2 - 扩展功能', () => {
  test('邀请成员 Modal', async ({ page }) => {
    await page.goto('/chat/1');
    await page.locator('button:has-icon(Icons.person_add)').click();
    await expect(page.locator('text=邀请成员')).toBeVisible();
  });

  test('附件上传 Modal', async ({ page }) => {
    await page.goto('/chat/1');
    await page.locator('button:has-icon(Icons.add)').click();
    await expect(page.locator('text=图片')).toBeVisible();
    await expect(page.locator('text=拍照')).toBeVisible();
    await expect(page.locator('text=文件')).toBeVisible();
  });

  test('打字状态指示器', async ({ page }) => {
    await page.goto('/chat/1');
    const input = page.locator('input[type="text"]').first();
    await input.fill('typing...');
    // Typing indicator should be triggered
  });
});