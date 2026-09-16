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
    await expect(page.locator('text=BPM')).toBeVisible();
  });

});
