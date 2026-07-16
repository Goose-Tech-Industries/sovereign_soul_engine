// @ts-check
const { test, expect } = require('@playwright/test');

const BASE = 'http://localhost:4002';

/**
 * Wait for the LiveView socket to connect and DOM to settle.
 */
async function waitForLiveView(page, extraMs = 500) {
  await page.waitForFunction(() => {
    return !!document.querySelector('[data-phx-main]');
  }, { timeout: 10_000 });
  await page.waitForTimeout(extraMs);
}

/**
 * Navigate using a LiveView link (push_navigate), then wait for the new view.
 */
async function liveNavigate(page, linkText) {
  await page.locator(`a:has-text("${linkText}")`).first().click();
  await waitForLiveView(page, 600);
}

/**
 * Force-open a <details> element and wait a tick.
 */
async function openDetails(page) {
  await page.locator('details').evaluateAll(elements => {
    elements.forEach(el => el.open = true);
  });
  await page.waitForTimeout(200);
}

/**
 * Click a named event inject button and ensure the details stay open for the result.
 */
async function injectEvent(page, eventType) {
  await openDetails(page);
  await page.locator(`#inject-${eventType}`).click();
  await page.waitForTimeout(400);
  await openDetails(page);
}

test.describe('Soul Core — Scene Interaction E2E', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto(BASE + '/sse');
    await waitForLiveView(page);
  });

  // ── 1. Dashboard smoke ────────────────────────────────────

  test('dashboard loads and shows characters, scenes, and navigation', async ({ page }) => {
    await expect(page.getByRole('heading', { level: 1, name: 'Sovereign Soul Engine' })).toBeVisible();
    await expect(page.locator('text=Vael').first()).toBeVisible();
    await expect(page.locator('text=Goose').first()).toBeVisible();
    await expect(page.locator('text=Testing Grounds')).toBeVisible();
    await expect(page.getByRole('link', { name: 'Soul Ledger' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Memory Vault' })).toBeVisible();
  });

  // ── 2. Navigate to scene and verify participants ──────────

  test('scene page loads with participants', async ({ page }) => {
    await page.getByRole('link', { name: 'Testing Grounds' }).click();
    await waitForLiveView(page);

    await expect(page.getByRole('heading', { level: 1, name: 'Testing Grounds' })).toBeVisible();
    await expect(page.locator('text=In scene:')).toBeVisible();
    await expect(page.locator('button:has-text("Vael")')).toBeVisible();
    await expect(page.locator('button:has-text("Goose")')).toBeVisible();
  });

  // ── 3. Soul Inspector for Vael ────────────────────────────

  test('soul inspector shows character emotions on click', async ({ page }) => {
    await page.getByRole('link', { name: 'Testing Grounds' }).click();
    await waitForLiveView(page);

    await page.locator('button:has-text("Vael")').click();
    await page.waitForTimeout(800);

    await expect(page.locator('text=Soul Inspector: Vael')).toBeVisible({ timeout: 5_000 });
    await expect(page.locator('text=Emotions')).toBeVisible();
    await expect(page.locator('text=Relationships')).toBeVisible();
    await expect(page.locator('text=Recent Memories')).toBeVisible();
  });

  // ── 4. Chat dialogue submission ───────────────────────────

  test('sends a dialogue message and sees it rendered', async ({ page }) => {
    await page.getByRole('link', { name: 'Testing Grounds' }).click();
    await waitForLiveView(page);

    const input = page.locator('#message-form input[type="text"]');
    await input.fill('Hello Vael, how are you holding up?');
    await page.locator('#send-message-btn').click();

    await expect(page.locator('#scene-messages')).toContainText('Hello Vael', { timeout: 8_000 });
    await expect(page.locator('#scene-messages')).toContainText('🧠 Private Thought:', { timeout: 15_000 });
  });

  // ── 5. Event injector — betrayed_me ───────────────────────

  test('injecting betrayed_me updates emotions and shows confirmation', async ({ page }) => {
    await page.getByRole('link', { name: 'Testing Grounds' }).click();
    await waitForLiveView(page);

    // Open soul inspector
    await page.locator('button:has-text("Vael")').click();
    await page.waitForTimeout(800);
    await expect(page.locator('text=Soul Inspector: Vael')).toBeVisible({ timeout: 5_000 });

    // Expand Event Injector
    await page.locator('text=Event Injector').click();
    await page.waitForTimeout(300);

    // Inject
    await injectEvent(page, 'betrayed_me');

    // Confirm the result text is present inside the now-open details
    await expect(page.locator('details')).toContainText('Injected betrayed_me', { timeout: 8_000 });

    // Soul Inspector still visible
    await expect(page.locator('text=Soul Inspector: Vael')).toBeVisible({ timeout: 3_000 });
  });

  // ── 6. Event injector — ally_saved_me ─────────────────────

  test('injecting ally_saved_me increases trust and gratitude', async ({ page }) => {
    await page.getByRole('link', { name: 'Testing Grounds' }).click();
    await waitForLiveView(page);

    await page.locator('button:has-text("Vael")').click();
    await page.waitForTimeout(800);
    await expect(page.locator('text=Soul Inspector: Vael')).toBeVisible({ timeout: 5_000 });

    await page.locator('text=Event Injector').click();
    await page.waitForTimeout(300);
    await injectEvent(page, 'ally_saved_me');

    await expect(page.locator('details')).toContainText('Injected ally_saved_me', { timeout: 8_000 });
  });

  // ── 7. State survives page reload ─────────────────────────

  test('messages and state survive page reload', async ({ page }) => {
    await page.getByRole('link', { name: 'Testing Grounds' }).click();
    await waitForLiveView(page);

    const input = page.locator('#message-form input[type="text"]');
    await input.fill('persistence-test-message');
    await page.locator('#send-message-btn').click();
    await expect(page.locator('#scene-messages')).toContainText('persistence-test-message', { timeout: 8_000 });

    await page.reload();
    await waitForLiveView(page);

    await expect(page.locator('#scene-messages')).toContainText('persistence-test-message', { timeout: 5_000 });
  });

  // ── 8. Navigation between views ───────────────────────────

  test('navigation between views works', async ({ page }) => {
    await page.getByRole('link', { name: 'Testing Grounds' }).click();
    await waitForLiveView(page);

    // Back to dashboard via the arrow link
    await page.locator('a:has-text("Dashboard")').first().click();
    await waitForLiveView(page);
    await expect(page.getByRole('heading', { level: 1, name: 'Sovereign Soul Engine' })).toBeVisible({ timeout: 5_000 });

    // Soul Ledger
    await page.getByRole('link', { name: 'Soul Ledger' }).click();
    await waitForLiveView(page);
    await expect(page.getByRole('heading', { level: 1, name: 'Soul Ledger' })).toBeVisible({ timeout: 5_000 });

    // Back to dashboard first, then Memory Vault (link only exists on dashboard)
    await page.locator('a:has-text("Dashboard")').first().click();
    await waitForLiveView(page);
    await page.getByRole('link', { name: 'Memory Vault' }).click();
    await waitForLiveView(page);
    await expect(page.getByRole('heading', { level: 1, name: 'Memory Vault' })).toBeVisible({ timeout: 5_000 });
  });

  // ── 9. Character profile for Vael ─────────────────────────

  test('character profile for Vael shows soul data', async ({ page }) => {
    // Click Vael character card on dashboard (the link wraps the whole card)
    await page.locator('a[href*="/characters/"]:has-text("Vael")').first().click();
    await waitForLiveView(page);

    await expect(page.getByRole('heading', { level: 1, name: 'Vael' })).toBeVisible({ timeout: 5_000 });
    await expect(page.getByRole('heading', { name: 'Soul Profile' })).toBeVisible({ timeout: 5_000 });
    await expect(page.getByRole('heading', { name: 'Emotional State' })).toBeVisible({ timeout: 5_000 });
  });

  // ── 10. Sequential events ─────────────────────────────────

  test('sequential betrayed then apologized events update accordingly', async ({ page }) => {
    await page.getByRole('link', { name: 'Testing Grounds' }).click();
    await waitForLiveView(page);

    await page.locator('button:has-text("Vael")').click();
    await page.waitForTimeout(800);
    await expect(page.locator('text=Soul Inspector: Vael')).toBeVisible({ timeout: 5_000 });

    await page.locator('text=Event Injector').click();
    await page.waitForTimeout(300);

    await injectEvent(page, 'betrayed_me');
    await expect(page.locator('details')).toContainText('Injected betrayed_me', { timeout: 8_000 });

    await injectEvent(page, 'apologized_to_me');
    await expect(page.locator('details')).toContainText('Injected apologized_to_me', { timeout: 8_000 });
  });

  // ── 11. Soul Ledger shows entries after event injection ────

  test('soul ledger displays entries after event injection', async ({ page }) => {
    await page.getByRole('link', { name: 'Testing Grounds' }).click();
    await waitForLiveView(page);

    await page.locator('text=Event Injector').click();
    await page.waitForTimeout(300);
    await injectEvent(page, 'praised_me');
    await expect(page.locator('details')).toContainText('Injected praised_me', { timeout: 8_000 });

    // Navigate to ledger via the dashboard
    await page.locator('a:has-text("Dashboard")').first().click();
    await waitForLiveView(page);
    await page.getByRole('link', { name: 'Soul Ledger' }).click();
    await waitForLiveView(page);

    await expect(page.locator('text=event_injected').first()).toBeVisible({ timeout: 5_000 });
  });

});
