const { chromium } = require('@playwright/test');
const path = require('path');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1.5 });
  
  await page.goto('http://localhost:8561/sse/chat?scene_id=a8d6f13e-e604-40aa-b993-220959563f79', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1000);
  
  const btn = page.locator('#neighborhood-drawer-btn');
  if (await btn.isVisible()) {
    await btn.click();
    await page.waitForTimeout(1000);
  }
  
  const outPath = path.resolve(__dirname, '../demo_video/test_neighborhood_preview.png');
  await page.screenshot({ path: outPath });
  console.log('Saved screenshot to:', outPath);
  
  await browser.close();
})();
