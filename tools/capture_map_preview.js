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

  // Click on "high_palace" to show inspector details for the High Sovereign Palace
  const palaceNode = page.locator("g[phx-value-slug='high_palace']");
  if (await palaceNode.isVisible()) {
    await palaceNode.click({ force: true });
    await page.waitForTimeout(1000);
  }

  const outPath = path.resolve(__dirname, '../demo_video/town_map_preview.png');
  await page.screenshot({ path: outPath });
  console.log('Saved Town Map screenshot to:', outPath);

  await browser.close();
})();
