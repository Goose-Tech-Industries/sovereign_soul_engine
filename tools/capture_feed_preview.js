const { chromium } = require('@playwright/test');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await page.goto('http://localhost:8561/sse/feed', { waitUntil: 'networkidle' });
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'demo_video/soulbook_feed_preview.png', fullPage: true });
  await browser.close();
  console.log('SOULBOOK_SCREENSHOT_DONE');
})();
