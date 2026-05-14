import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests-e2e/tests',
  timeout: 60000,
  retries: 0,
  use: {
    baseURL: 'http://localhost:3030',
    trace: 'on-first-retry',
    headless: true,
    executablePath: '/vol4/1000/nas4/tool/chrome-linux64/chrome',
    launchOptions: {
      args: ['--disable-web-security', '--disable-gpu', '--no-sandbox'],
    },
  },
  projects: [
    {
      name: 'chromium',
      use: { browserName: 'chromium' },
    },
  ],
});