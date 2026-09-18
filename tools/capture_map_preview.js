const { chromium } = require('@playwright/test');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  
  await page.goto('http://localhost:8561/sse/map', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1000);
  
  // 1. Initial Palace Position with Player Token
  await page.screenshot({ path: 'demo_video/town_map_walkable_preview.png', fullPage: false });
  console.log('WALKABLE_MAP_SCREENSHOT_1_SAVED');

  // 2. Walk North to Crow's Keep using keyboard 'w'
  await page.keyboard.press('w');
  await page.waitForTimeout(1000);
  await page.screenshot({ path: 'demo_video/town_map_crows_keep_preview.png', fullPage: false });
  console.log('WALKABLE_MAP_SCREENSHOT_2_SAVED');

  // 3. Hail an NPC if present
  const hailBtn = await page.$('button[phx-click="hail_soul"]');
  if (hailBtn) {
    await hailBtn.click();
    await page.waitForTimeout(800);
    await page.screenshot({ path: 'demo_video/town_map_hail_preview.png', fullPage: false });
    console.log('WALKABLE_MAP_SCREENSHOT_3_SAVED');
  }

  await browser.close();
  console.log('ALL_PREVIEWS_COMPLETE');
})();
