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
        pill.style.backgroundColor = 'rgba(15, 23, 42, 0.92)';
        pill.style.backdropFilter = 'blur(12px)';
        pill.style.border = '1px solid rgba(249, 115, 22, 0.4)';
        pill.style.borderRadius = '9999px';
        pill.style.padding = '10px 24px';
        pill.style.color = '#ffffff';
        pill.style.fontFamily = 'system-ui, -apple-system, sans-serif';
        pill.style.zIndex = '999999';
        pill.style.boxShadow = '0 20px 35px -5px rgba(0, 0, 0, 0.5), 0 0 20px rgba(249, 115, 22, 0.2)';
        pill.style.textAlign = 'center';
        pill.style.transition = 'all 0.3s cubic-bezier(0.16, 1, 0.3, 1)';
        document.body.appendChild(pill);
      }
      pill.innerHTML = `
        <div style="font-size: 10px; font-weight: 800; letter-spacing: 0.12em; color: #f97316; text-transform: uppercase; margin-bottom: 2px;">${category}</div>
        <div style="font-size: 15px; font-weight: 600; color: #f8fafc; letter-spacing: -0.01em;">${text}</div>
      `;
    }, { text, category });
  }

  // --- 0:00 to 0:07 | HERO & INTRO ---
  console.log('📍 0:00 - Loading Hero...');
  await page.goto(BASE_URL + '/', { waitUntil: 'networkidle' });
  await showSubtitle('AI Companions with Persistent Lives & True Souls', 'CORE BREAKTHROUGH');
  await page.waitForTimeout(6500);

  // --- 0:07 to 0:16 | BIOMETRIC SANDBOX ---
  console.log('📍 0:07 - Biometric Adrenaline Spike...');
  const sandbox = page.locator('#sandbox-bpm-slider');
  if (await sandbox.isVisible()) {
    await sandbox.scrollIntoViewIfNeeded();
    await showSubtitle('Real-Time Biometric Reactivity: Heart Rate Spikes to 145 BPM', 'THEORY OF MIND');
    await page.waitForTimeout(1000);

    // Smoothly drag BPM
    for (let bpm = 75; bpm <= 145; bpm += 10) {
      await sandbox.fill(String(bpm));
      await page.waitForTimeout(80);
    }
    await sandbox.fill('145');
    await page.waitForTimeout(3000);

    await showSubtitle('Theory of Mind triggers instant psychological & emotional shift', 'ADRENALINE ALERT');
    await page.waitForTimeout(4000);
  }

  // --- 0:16 to 0:25 | TOWN SQUARE & NEIGHBORHOOD BOARD ---
  console.log('📍 0:16 - Moving into Chat & Town Square...');
  await page.goto(BASE_URL + '/sse/chat', { waitUntil: 'networkidle' });
  await showSubtitle('Living Soul Society: 50 autonomous agents living when you log off', 'DECENTRALIZED TOWN');
  await page.waitForTimeout(2000);

  const drawerBtn = page.locator('#neighborhood-drawer-btn');
  if (await drawerBtn.isVisible()) {
    await drawerBtn.click();
    console.log('   Opened Neighborhood Radar Drawer');
    await showSubtitle('Autonomous Gossip, Community Alerts & Passive Drift', 'SOUL SOCIETY RADAR');
    await page.waitForTimeout(6000);
  }

  // --- 0:25 to 0:33 | THE OUTRO ---
  console.log('📍 0:25 - Closing Scene & Outro...');
  await showSubtitle('Welcome to a Real Artificial Life. Own Your Companion.', 'PORTABLE .SOUL CAPSULE');
  await page.waitForTimeout(8000);

  console.log('🏁 Finalizing Playwright context...');
  const video = page.video();
  const rawVideoPath = await video.path();

  await context.close();
  await browser.close();

  console.log(`✅ Raw WebM saved at: ${rawVideoPath}`);

  // Transcode and merge audio with ffmpeg
  const finalMp4Path = path.join(OUT_DIR, 'twitter_demo_voiced.mp4');
  console.log(`🎬 Merging ElevenLabs audio into final MP4: ${finalMp4Path}...`);

  // ffmpeg command to:
  // 1. Take raw video input (-i rawVideoPath)
  // 2. Take ElevenLabs audio input (-i AUDIO_PATH)
  // 3. Map video and audio, encode to H.264 + AAC, faststart for Twitter
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
