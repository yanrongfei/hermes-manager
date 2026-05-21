import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests-e2e/tests',
  timeout: 60000,
  retries: 0,
  use: {
    baseURL: 'http://localhost:3003',
    trace: 'on-first-retry',
    headless: true,
    executablePath: '/vol4/1000/nas4/tool/chrome-linux64/chrome',
    launchOptions: {
      args: [
        '--disable-web-security',
        '--no-sandbox',
        '--disable-service-worker',
        '--disable-gpu',
        '--disable-software-rasterizer',
        '--disable-accelerated-2d-canvas',
        '--disable-accelerated-jpeg-decoding',
        '--disable-accelerated-video-decode',
        '--use-gl=angle',
        '--use-angle=swiftshader-webgl',
        '--enable-webgl',
        '--ignore-gpu-blocklist'
      ],
    },
  },
  projects: [
    {
      name: 'chromium',
      use: { browserName: 'chromium' },
    },
  ],
});