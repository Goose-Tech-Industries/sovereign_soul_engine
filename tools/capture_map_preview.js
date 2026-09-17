const { chromium } = require('@playwright/test');
const path = require('path');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1.5
  });

  console.log('Navigating to /sse/map...');
  await page.goto('http://localhost:8561/sse/map', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1500);

  // Click on "old_ironworks" to show inspector details for Maya's foundry
  const ironworksNode = page.locator("g[phx-value-slug='old_ironworks']");
  if (await ironworksNode.isVisible()) {
    await ironworksNode.click();
    await page.waitForTimeout(1000);
  }

  const outPath = path.resolve(__dirname, '../demo_video/town_map_preview.png');
  await page.screenshot({ path: outPath });
  console.log('Saved Town Map screenshot to:', outPath);

  await browser.close();
})();
