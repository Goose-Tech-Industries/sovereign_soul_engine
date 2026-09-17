// @ts-check
const { chromium } = require('@playwright/test');
const { execSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const BASE_URL = process.env.BASE_URL || 'http://localhost:8561';
const OUT_DIR = path.resolve(__dirname, '../demo_video');
const RAW_DIR = path.join(OUT_DIR, 'raw');

fs.mkdirSync(RAW_DIR, { recursive: true });

async function run() {
  console.log('🎬 Launching Playwright Chromium for Twitter Demo Recording...');
  console.log(`Target: ${BASE_URL}`);

  const browser = await chromium.launch({
    headless: true // runs cleanly in background
  });

  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    deviceScaleFactor: 1,
    recordVideo: {
      dir: RAW_DIR,
      size: { width: 1280, height: 720 }
    }
  });

  const page = await context.newPage();

  console.log('📍 1. Loading Landing Page & Hero...');
  await page.goto(BASE_URL + '/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1000);

  // Take Hero Screenshot
  await page.screenshot({ path: path.join(OUT_DIR, '01_hero.png') });
  await page.waitForTimeout(2000);

  console.log('📍 2. Interacting with Biometric Sandbox...');
  const sandbox = page.locator('#sandbox-bpm-slider');
  if (await sandbox.isVisible()) {
    await sandbox.scrollIntoViewIfNeeded();
    await page.waitForTimeout(1000);

    // Slide BPM to 145 (Adrenaline Spike)
    console.log('   Spiking heart rate to 145 BPM...');
    await sandbox.fill('145');
    await page.waitForTimeout(1500);

    await page.screenshot({ path: path.join(OUT_DIR, '02_biometric_spike.png') });
    await page.waitForTimeout(1500);

    // Switch to Ravina
    console.log('   Switching companion to Ravina...');
    const ravinaBtn = page.locator('button:has-text("Ravina")').first();
    if (await ravinaBtn.isVisible()) {
      await ravinaBtn.click();
      await page.waitForTimeout(1500);
    }
  }

  console.log('📍 3. Navigating to Chat Room (/sse/chat)...');
  const chatBtn = page.locator('#hero-chat-btn');
  if (await chatBtn.isVisible()) {
    await chatBtn.click();
  } else {
    await page.goto(BASE_URL + '/sse/chat', { waitUntil: 'networkidle' });
  }

  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(OUT_DIR, '03_companion_chat.png') });

  console.log('📍 4. Simulating Companion Interaction...');
  const chatInput = page.locator('#chat-input');
  if (await chatInput.isVisible()) {
    await chatInput.scrollIntoViewIfNeeded();
    await chatInput.click();
    await page.waitForTimeout(500);

    const message = "Maya, how was the square today while I was away?";
    for (const char of message) {
      await chatInput.pressSequentially(char, { delay: 40 });
    }
    await page.waitForTimeout(800);

    const sendBtn = page.locator('#chat-send-btn');
    if (await sendBtn.isVisible()) {
      await sendBtn.click();
      console.log('   Sent question to Maya...');
      await page.waitForTimeout(3000);
    }
  }

  console.log('📍 5. Opening Neighborhood Board / Town Drama Drawer...');
  const drawerBtn = page.locator('#neighborhood-drawer-btn');
  if (await drawerBtn.isVisible()) {
    await drawerBtn.click();
    console.log('   Opened Neighborhood Drawer!');
    await page.waitForTimeout(2500);
    await page.screenshot({ path: path.join(OUT_DIR, '04_town_drama.png') });
    await page.waitForTimeout(2000);
  }

  console.log('🏁 Finalizing Recording...');
  await page.waitForTimeout(1000);

  // Get video object before closing context
  const video = page.video();
  const rawVideoPath = await video.path();

  await context.close();
  await browser.close();

  console.log(`✅ Raw WebM video saved at: ${rawVideoPath}`);

  // Transcode to MP4 using ffmpeg for Twitter
  const mp4Path = path.join(OUT_DIR, 'twitter_demo.mp4');
  console.log(`🎬 Transcoding to Twitter-ready MP4: ${mp4Path}...`);

  try {
    execSync(`ffmpeg -y -i "${rawVideoPath}" -c:v libx264 -preset fast -crf 22 -pix_fmt yuv420p -movflags +faststart "${mp4Path}"`, {
      stdio: 'inherit'
    });
    console.log(`\n🎉 TWITTER DEMO VIDEO READY: ${mp4Path}`);
  } catch (err) {
    console.warn(`ffmpeg transcoding error: ${err.message}. Raw WebM is still available at ${rawVideoPath}`);
  }
}

run().catch((err) => {
  console.error('Recording failed:', err);
  process.exit(1);
});
