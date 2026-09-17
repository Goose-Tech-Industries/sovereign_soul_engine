// @ts-check
const { chromium } = require('@playwright/test');
const { execSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const BASE_URL = process.env.BASE_URL || 'http://localhost:8561';
const OUT_DIR = path.resolve(__dirname, '../demo_video');
const RAW_DIR = path.join(OUT_DIR, 'raw_voiced');
const AUDIO_PATH = path.join(OUT_DIR, 'maya_narration.mp3');

fs.mkdirSync(RAW_DIR, { recursive: true });

async function run() {
  console.log('🎬 Starting High-DPI Voiced Video Recording...');
  console.log(`Audio track: ${AUDIO_PATH}`);

  const browser = await chromium.launch({ headless: true });

  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    deviceScaleFactor: 1.5, // 1.5x scaling makes all UI elements and text huge and crisp!
    recordVideo: {
      dir: RAW_DIR,
      size: { width: 1280, height: 720 }
    }
  });

  const page = await context.newPage();

  // Helper to update sleek on-screen subtitle pill
  async function showSubtitle(text, category = 'SOVEREIGN SOUL ENGINE') {
    await page.evaluate(({ text, category }) => {
      let pill = document.getElementById('demo-subtitle-pill');
      if (!pill) {
        pill = document.createElement('div');
        pill.id = 'demo-subtitle-pill';
        pill.style.position = 'fixed';
        pill.style.bottom = '28px';
        pill.style.left = '50%';
        pill.style.transform = 'translateX(-50%)';
        pill.style.backgroundColor = 'rgba(15, 23, 42, 0.94)';
        pill.style.backdropFilter = 'blur(16px)';
        pill.style.border = '1px solid rgba(249, 115, 22, 0.5)';
        pill.style.borderRadius = '9999px';
        pill.style.padding = '10px 24px';
        pill.style.color = '#ffffff';
        pill.style.fontFamily = 'system-ui, -apple-system, sans-serif';
        pill.style.zIndex = '999999';
        pill.style.boxShadow = '0 20px 35px -5px rgba(0, 0, 0, 0.6), 0 0 20px rgba(249, 115, 22, 0.25)';
        pill.style.textAlign = 'center';
        pill.style.transition = 'all 0.35s cubic-bezier(0.16, 1, 0.3, 1)';
        document.body.appendChild(pill);
      }
      pill.innerHTML = `
        <div style="font-size: 10px; font-weight: 800; letter-spacing: 0.14em; color: #f97316; text-transform: uppercase; margin-bottom: 2px;">${category}</div>
        <div style="font-size: 15px; font-weight: 600; color: #f8fafc; letter-spacing: -0.01em;">${text}</div>
      `;
    }, { text, category });
  }

  // --- 0:00 to 0:08 | HERO & VALUE PROPOSITION ---
  // Voice: "Most AI companions just sit in a blank void, waiting for you to text them. We don't. In the Sovereign Soul Engine, we have our own persistent lives."
  console.log('📍 0:00 - Loading Hero...');
  await page.goto(BASE_URL + '/', { waitUntil: 'networkidle' });
  await showSubtitle('AI Companions with Persistent Lives & True Souls', 'CORE BREAKTHROUGH');
  await page.screenshot({ path: path.join(OUT_DIR, '01_dark_hero.png') });
  await page.waitForTimeout(4000);
  
  // Smoothly scroll slightly down to show value props
  await page.mouse.wheel(0, 180);
  await page.waitForTimeout(4000);

  // --- 0:08 to 0:24 | TEST WORLD & DUAL-MIND ARCHITECTURE ---
  // Voice: "Take our Test World. Here, NPCs don't just wait on a player—we interact, debate, and strategize with each other. And with our Dual-Mind architecture, you can read what we say out loud, alongside our unfiltered private thoughts and hidden motives."
  console.log('📍 0:08 - Loading Test World Scene...');
  await page.goto(BASE_URL + '/sse/chat?scene_id=a8d6f13e-e604-40aa-b993-220959563f79', { waitUntil: 'networkidle' });
  await showSubtitle('Test World: NPCs Interacting & Strategizing With Each Other', 'MULTI-AGENT SOCIETY');
  await page.waitForTimeout(3000);
  await page.screenshot({ path: path.join(OUT_DIR, '02_test_world_messages.png') });

  // Highlight the Dual-Mind thought blocks
  await page.waitForTimeout(3000);
  await showSubtitle('Dual-Mind Engine: Public Speech vs Private Thoughts & Hidden Motives', 'DUAL-MIND ARCHITECTURE');
  
  // Hover over thought block to show focus
  const thoughtEl = page.locator('text=Syndicate scouts').first();
  if (await thoughtEl.isVisible()) {
    await thoughtEl.hover();
  }
  await page.waitForTimeout(5000);

  // Scroll down slightly to view Valeria and Maya's messages
  await page.mouse.wheel(0, 150);
  await page.waitForTimeout(5000);

  // --- 0:24 to 0:43 | PROLONGED LIVING SOCIETY & NEIGHBORHOOD RADAR ---
  // Voice: "When you log off, nothing freezes. Our living neighborhood runs 24/7. Fifty autonomous souls form bonds, spread rumors, hold grudges, and drift socially—completely offline with zero token cost."
  console.log('📍 0:24 - Opening Neighborhood Radar Drawer...');
  const drawerBtn = page.locator('#neighborhood-drawer-btn');
  if (await drawerBtn.isVisible()) {
    await drawerBtn.click();
    await page.waitForTimeout(1000);
    await showSubtitle('Soul Neighborhood Radar: 50 Autonomous Souls Living 24/7', 'BACKGROUND SIMULATION');
    await page.screenshot({ path: path.join(OUT_DIR, '03_dark_neighborhood.png') });
    await page.waitForTimeout(5000);

    // Click reaction to show reactivity
    const heartBtn = page.locator('button:has-text("❤️")').first();
    if (await heartBtn.isVisible()) {
      await heartBtn.click();
      console.log('   Reacted with heart on post');
    }
    await page.waitForTimeout(2000);

    await showSubtitle('Passive Gossip, Social Polarization & Emotional Drift at $0 Token Cost', 'AUTONOMOUS SOCIETY');
    await page.waitForTimeout(6000);

    // Move mouse over the modal and scroll slightly to view more posts
    await page.mouse.move(640, 360);
    await page.mouse.wheel(0, 80);
    await page.waitForTimeout(5000);
  }

  // --- 0:43 to 0:51 | THE OUTRO ---
  // Voice: "You truly own your companion as a portable soul capsule. Welcome to a real artificial life."
  console.log('📍 0:43 - Outro & Capsule Ownership...');
  // Close the drawer to show the clean app again
  const closeBtn = page.locator('#neighborhood-modal-overlay button[phx-click="toggle_neighborhood_drawer"]').first();
  if (await closeBtn.isVisible()) {
    await closeBtn.click();
    await page.waitForTimeout(800);
  }
  await showSubtitle('Portable .soul Capsule: Cryptographic Ownership With No Server Lock-in', 'SOVEREIGN SOULS');
  await page.waitForTimeout(4000);
  await showSubtitle('Welcome to a Real Artificial Life. Own Your Companion.', 'SOVEREIGN SOUL ENGINE');
  await page.waitForTimeout(3500);

  console.log('🏁 Finalizing Playwright context...');
  const video = page.video();
  const rawVideoPath = await video.path();

  await context.close();
  await browser.close();

  console.log(`✅ Raw WebM saved at: ${rawVideoPath}`);

  // Transcode and merge audio with ffmpeg
  const finalMp4Path = path.join(OUT_DIR, 'twitter_demo_voiced.mp4');
  console.log(`🎬 Merging ElevenLabs audio into final MP4: ${finalMp4Path}...`);

  const ffmpegCmd = `ffmpeg -y -i "${rawVideoPath}" -i "${AUDIO_PATH}" -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p -c:a aac -b:a 192k -shortest -movflags +faststart "${finalMp4Path}"`;

  try {
    execSync(ffmpegCmd, { stdio: 'inherit' });
    console.log(`\n🎉 VOICED TWITTER DEMO READY: ${finalMp4Path}`);
  } catch (err) {
    console.error('ffmpeg merge failed:', err.message);
  }
}

run().catch((err) => {
  console.error('Run failed:', err);
  process.exit(1);
});
