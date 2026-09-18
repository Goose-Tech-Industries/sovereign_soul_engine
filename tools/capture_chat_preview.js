const { chromium } = require('@playwright/test');
const path = require('path');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1.5 });
  
  await page.goto('http://localhost:8561/sse/chat', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1000);
  
  // Click Age Gate Accept if present
  const gateBtn = page.getByRole('button', { name: /I Am 18\+/i });
  if (await gateBtn.isVisible()) {
    await gateBtn.click();
    await page.waitForTimeout(1000);
  }
  
  const outPath = path.resolve(__dirname, '../demo_video/chat_companion_preview.png');
  await page.screenshot({ path: outPath });
  console.log('Saved companion chat preview to:', outPath);
  
  await browser.close();
})();
