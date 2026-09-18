const { chromium } = require('@playwright/test');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });

  // 1. Landing Page with $14.99 & $19.99 Pricing Cards
  await page.goto('http://localhost:8561/#pricing', { waitUntil: 'networkidle' });
  await page.waitForTimeout(800);
  await page.screenshot({ path: 'demo_video/landing_page_pricing_preview.png', fullPage: false });
  console.log('LANDING_PRICING_SCREENSHOT_DONE');

  // 2. Billing & Age Verification Control Center
  await page.goto('http://localhost:8561/sse/billing', { waitUntil: 'networkidle' });
  await page.waitForTimeout(800);
  await page.screenshot({ path: 'demo_video/billing_page_preview.png', fullPage: false });
  console.log('BILLING_PAGE_SCREENSHOT_DONE');

  // 3. Activate Archon 18+ Tier
  const archonBtn = await page.$("button[phx-value-tier_id='archon_1999']");
  if (archonBtn) {
    await archonBtn.click();
    await page.waitForTimeout(800);
    await page.screenshot({ path: 'demo_video/billing_archon_activated_preview.png', fullPage: false });
    console.log('ARCHON_ACTIVATED_SCREENSHOT_DONE');
  }

  await browser.close();
  console.log('ALL_BILLING_SCREENSHOTS_DONE');
})();
