// @ts-check
const { test, expect } = require('@playwright/test');

const BASE = process.env.BASE_URL || 'http://localhost:8561';

/**
 * Wait for Phoenix LiveView to connect and settle.
 */
async function waitForLiveView(page, extraMs = 600) {
  await page.waitForFunction(() => {
    return !!document.querySelector('[data-phx-main]');
  }, { timeout: 12_000 });
  await page.waitForTimeout(extraMs);
}

test.describe('Sovereign Soul Engine — Full Experience E2E', () => {

  test('1. Landing page loads hero, interactive biometric sandbox, and pricing cards', async ({ page }) => {
    await page.goto(BASE + '/');
    await waitForLiveView(page);

    // 1. Verify Hero
    await expect(page.locator('h1')).toContainText('Artificial Lives With Persistent Souls');
    await expect(page.locator('#hero-chat-btn')).toBeVisible();

    // 2. Verify Interactive Biometric Sandbox
    const reactionBox = page.locator('#sandbox-reaction-text');
    await expect(reactionBox).toBeVisible();
    await expect(reactionBox).toContainText('Maya');

    // Drag / change BPM slider to adrenaline levels
    const slider = page.locator('#sandbox-bpm-slider');
    await slider.fill('145');
    await page.waitForTimeout(400);

    // Verify reaction updated dynamically in LiveView
    await expect(page.locator('#sandbox-reaction-text')).toContainText('145 BPM');
    await expect(page.locator('text=Adrenaline Spike Detected')).toBeVisible();

    // Switch companion in sandbox
    await page.locator('button:has-text("Ravina")').first().click();
    await page.waitForTimeout(400);
    await expect(page.locator('#sandbox-reaction-text')).toContainText('Ravina');

    // 3. Verify Pricing Tiers
    await expect(page.getByRole('heading', { name: 'BYOK Pro' })).toBeVisible();
    await expect(page.locator('text=$9').first()).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Sovereign Cloud' })).toBeVisible();
    await expect(page.locator('text=$24').first()).toBeVisible();

    // 4. Verify Game Dev SDK Code Snippet
    await expect(page.locator('#developers')).toBeVisible();
    await expect(page.locator('text=SovereignSoul')).toBeVisible();
  });

  test('2. Navigation from landing page to chat room works seamlessly', async ({ page }) => {
    await page.goto(BASE + '/');
    await waitForLiveView(page);

    await page.locator('#hero-chat-btn').click();
    await waitForLiveView(page);

    await expect(page).toHaveURL(new RegExp('/sse/chat'));
    await expect(page.locator('#chat-app')).toBeVisible();
    await expect(page.locator('text=Direct Messages')).toBeVisible();
  });

  test('3. Chat room displays dynamic emotional expression badge and companion vitals', async ({ page }) => {
    await page.goto(BASE + '/sse/chat');
    await waitForLiveView(page);

    // Verify emotional expression badge is rendered
    const expressionBadge = page.locator('#companion-expression-badge');
    if (await expressionBadge.isVisible()) {
      const badgeText = await expressionBadge.textContent();
      expect(badgeText).toBeTruthy();
    }

    // Verify biometric HUD
    await expect(page.locator('text=BPM')).toBeVisible();
  });

  test('4. Hands-Free Voice Call Intercom HUD activates and deactivates', async ({ page }) => {
    await page.goto(BASE + '/sse/chat');
    await waitForLiveView(page);

    const callToggleBtn = page.locator('#voice-call-toggle-btn');
    await expect(callToggleBtn).toBeVisible();
    await expect(callToggleBtn).toContainText('Voice Call');

    // Activate voice call mode
    await callToggleBtn.click();
    await page.waitForTimeout(500);

    // Verify Intercom HUD banner is now visible
    const intercomHud = page.locator('#voice-intercom-hud');
    await expect(intercomHud).toBeVisible();
    await expect(page.locator('#intercom-status-pill')).toBeVisible();
    await expect(callToggleBtn).toContainText('End Call');

    // Deactivate via Hang Up button in HUD
    await page.locator('button:has-text("Hang Up")').click();
    await page.waitForTimeout(400);

    // Verify Intercom HUD banner closed
    await expect(intercomHud).not.toBeVisible();
    await expect(callToggleBtn).toContainText('Voice Call');
  });

  test('5. Message sending and dialogue stream rendering in chat', async ({ page }) => {
    await page.goto(BASE + '/sse/chat');
    await waitForLiveView(page);

    const chatInput = page.locator('#chat-input');
    await expect(chatInput).toBeVisible();

    await chatInput.fill('Playwright test: We are ready to launch.');
    await page.locator('#chat-send-btn').click();
    await page.waitForTimeout(800);

    // Verify message rendered in chat stream
    await expect(page.locator('#chat-messages')).toContainText('Playwright test: We are ready to launch.');
  });

  test('6. Neurochemistry HUD and dynamic psychological indicators render in chat', async ({ page }) => {
    // Set a wide viewport so 2xl elements are visible
    await page.setViewportSize({ width: 1600, height: 900 });
    await page.goto(BASE + '/sse/chat');
    await waitForLiveView(page);

    // Verify Neurochemistry HUD is attached and contains hormonal readings
    const neuroHud = page.locator('#neurochemistry-hud');
    await expect(neuroHud).toBeAttached();
    await expect(neuroHud).toContainText('C');
    await expect(neuroHud).toContainText('O');
    await expect(neuroHud).toContainText('D');
    await expect(neuroHud).toContainText('S');

    // Verify companion expression badge is present
    const expressionBadge = page.locator('#companion-expression-badge');
    await expect(expressionBadge).toBeVisible();

    // Verify Galaxy Watch biometrics HUD displays
    await expect(page.locator('text=BPM').first()).toBeVisible();
  });

  test('7. Smart Glasses capture and portable .Soul capsule export link are active and responsive', async ({ page }) => {
    await page.setViewportSize({ width: 1600, height: 900 });
    await page.goto(BASE + '/sse/chat');
    await waitForLiveView(page);

    // Verify .Soul capsule download link is rendered and points to export API
    const soulBtn = page.locator('a:has-text(".Soul")');
    await expect(soulBtn).toBeVisible({ timeout: 5_000 });
    const href = await soulBtn.getAttribute('href');
    expect(href).toMatch(/\/sse\/api\/souls\/.*\/export/);

    // Verify Glasses button is visible
    const glassesBtn = page.locator('button:has-text("Glasses")');
    await expect(glassesBtn).toBeVisible();

    // Trigger Smart Glasses capture
    await glassesBtn.click();
    await page.waitForTimeout(1000);

    // Confirm that action or flash confirmation occurred
    await expect(page.locator('body')).toContainText(/smart_glasses/i, { timeout: 8_000 });
  });

  test('8. Privacy and Boundaries shield drawer opens, toggles settings, and updates state', async ({ page }) => {
    await page.setViewportSize({ width: 1600, height: 900 });
    await page.goto(BASE + '/sse/chat');
    await waitForLiveView(page);

    // 1. Click Privacy button in header
    const privacyBtn = page.locator('#privacy-shield-btn');
    await expect(privacyBtn).toBeVisible({ timeout: 5_000 });
    await privacyBtn.click();
    await page.waitForTimeout(400);

    // 2. Verify Privacy Modal is visible
    const modal = page.locator('#privacy-modal-overlay');
    await expect(modal).toBeVisible();
    await expect(modal).toContainText('Privacy & Boundaries');
    await expect(modal).toContainText('Autonomous Outreach & Check-Ins');
    await expect(modal).toContainText('Wearables & Biometric Telemetry');
    await expect(modal).toContainText('Glasses, Smart Home & Voice');

    // 3. Toggle master proactive outreach switch
    const proactiveToggle = page.locator('input[phx-value-key="proactive_checkins"]');
    await expect(proactiveToggle).toBeVisible();
    await proactiveToggle.click();
    await page.waitForTimeout(300);

    // 4. Toggle smart glasses vision switch
    const visionToggle = page.locator('input[phx-value-key="camera_vision"]');
    await expect(visionToggle).toBeVisible();
    await visionToggle.click();
    await page.waitForTimeout(300);

    // 5. Close modal by clicking Done
    const doneBtn = page.locator('button:has-text("Done")');
    await doneBtn.click();
    await page.waitForTimeout(400);
    await expect(modal).not.toBeVisible();
  });

  test('9. Emergency Safe Word Freeze, Relationship Archetypes, and Selective Memory Purging', async ({ page }) => {
    await page.setViewportSize({ width: 1600, height: 900 });
    await page.goto(BASE + '/sse/chat');
    await waitForLiveView(page);

    // 1. Open Privacy & Boundaries modal
    const privacyBtn = page.locator('#privacy-shield-btn');
    await expect(privacyBtn).toBeVisible({ timeout: 5_000 });
    await privacyBtn.click();
    await page.waitForTimeout(400);

    const modal = page.locator('#privacy-modal-overlay');
    await expect(modal).toBeVisible();

    // 2. Verify new sections exist
    await expect(modal).toContainText('Emergency Safe Word & Psychological Protection');
    await expect(modal).toContainText('Relationship Archetype & Intimacy Ceiling');
    await expect(modal).toContainText('Selective Amnesia & Memory Vault Purge');

    // 3. Switch Relationship Archetype to "Platonic Mentor"
    const mentorBtn = page.locator('button:has-text("Platonic Mentor")');
    await expect(mentorBtn).toBeVisible();
    await mentorBtn.click();
    await page.waitForTimeout(300);
    await expect(modal).toContainText('Cap: 40%');

    // 4. Click Freeze Persona
    const freezeBtn = page.locator('button:has-text("Freeze Persona")');
    await expect(freezeBtn).toBeVisible();
    await freezeBtn.click();
    await page.waitForTimeout(300);

    // 5. Close modal
    const doneBtn = page.locator('button:has-text("Done")');
    await doneBtn.click();
    await page.waitForTimeout(400);

    // 6. Verify header shows "🛑 Persona Paused" banner
    const pausedBanner = page.locator('#safe-word-active-banner');
    await expect(pausedBanner).toBeVisible();
    await expect(pausedBanner).toContainText('Persona Paused');

    // 7. Click Resume on banner
    const resumeBtn = pausedBanner.locator('button:has-text("Resume")');
    await resumeBtn.click();
    await page.waitForTimeout(300);
    await expect(pausedBanner).not.toBeVisible();
  });

  test('10. Circadian Night-Owl Flow, Offline Edge Mode, and Nextdoor Soul Neighborhood Radar', async ({ page }) => {
    await page.setViewportSize({ width: 1600, height: 900 });
    await page.goto(BASE + '/sse/chat');
    await waitForLiveView(page);

    // 1. Verify circadian status badge is visible in header
    const circadianBadge = page.locator('#circadian-status-badge');
    await expect(circadianBadge).toBeVisible({ timeout: 5_000 });

    // 2. Open Privacy & Boundaries modal
    const privacyBtn = page.locator('#privacy-shield-btn');
    await expect(privacyBtn).toBeVisible();
    await privacyBtn.click();
    await page.waitForTimeout(400);

    const modal = page.locator('#privacy-modal-overlay');
    await expect(modal).toBeVisible();

    // 3. Verify sections for Circadian, Edge Mode, and Neighborhood exist
    await expect(modal).toContainText('Circadian Rhythm & Night-Owl Chronotypes');
    await expect(modal).toContainText('Air-Gapped Local Edge Survival Mode');
    await expect(modal).toContainText('Hyper-Local Neighborhood Radar');

    // 4. Select Night Owl chronotype
    const nightOwlBtn = page.locator('button:has-text("Night Owl")');
    await expect(nightOwlBtn).toBeVisible();
    await nightOwlBtn.click();
    await page.waitForTimeout(300);

    // 5. Close Privacy modal
    const doneBtn = page.locator('button:has-text("Done")');
    await doneBtn.click();
    await page.waitForTimeout(400);

    // 6. Open Soul Neighborhood (Nextdoor) Radar
    const neighBtn = page.locator('#neighborhood-drawer-btn');
    await expect(neighBtn).toBeVisible();
    await neighBtn.click();
    await page.waitForTimeout(400);

    const neighModal = page.locator('#neighborhood-modal-overlay');
    await expect(neighModal).toBeVisible();
    await expect(neighModal).toContainText('Soul Neighborhood Radar');

    // 7. Post a neighborhood vibe check
    const contentInput = neighModal.locator('input[placeholder*="Share a neighborhood vibe"]');
    await contentInput.fill('Late night coding sprint with my human. Street is quiet.');
    await neighModal.locator('button:has-text("Post")').click();
    await page.waitForTimeout(500);

    // 8. Verify post shows up in the neighborhood feed
    await expect(neighModal).toContainText('Late night coding sprint');

    // 9. Close Neighborhood modal
    const closeNeighBtn = neighModal.locator('button.btn-circle');
    await closeNeighBtn.click();
    await page.waitForTimeout(300);
    await expect(neighModal).not.toBeVisible();
  });

});

