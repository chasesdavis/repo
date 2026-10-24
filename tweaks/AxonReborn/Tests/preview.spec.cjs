// Optional browser verification. Install Playwright before running this file.
// AXON_CHROMIUM can point at an existing Chromium executable.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const { pathToFileURL } = require('node:url');
const path = require('node:path');
(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.AXON_CHROMIUM ? { executablePath: process.env.AXON_CHROMIUM } : {}) });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1100 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(pathToFileURL(path.join(__dirname, '../Design/preview.html')).href);
    assert.equal(await page.locator('.card').count(), 8);
    await page.getByRole('button', { name: 'Messages, 3 notifications', exact: true }).click();
    assert.equal(await page.locator('.card').count(), 3);
    await page.getByRole('button', { name: 'Add sample notification' }).click();
    assert.equal(await page.locator('.card').count(), 4);
    await page.locator('#private').check();
    assert.equal(await page.getByText('Notification preview hidden', { exact: true }).count(), 4);
    assert.equal(await page.getByText('Alex', { exact: true }).count(), 0);
    await page.getByRole('button', { name: 'Clear displayed samples' }).click();
    assert.equal(await page.locator('.pill[aria-pressed="true"]').getAttribute('data-app'), 'all');
    assert.equal(await page.locator('.card').count(), 5);
    await page.getByRole('button', { name: 'Reset demo' }).click();
    await page.locator('#compact').check();
    assert.equal(await page.locator('.pill-label').count(), 1);
    await page.locator('#counts').uncheck();
    assert.equal(await page.locator('.pill-count').count(), 0);
    await page.getByRole('button', { name: 'Reset demo' }).click();
    await page.getByRole('button', { name: 'Most notifications', exact: true }).click();
    assert.equal(await page.locator('.pill').nth(1).getAttribute('data-app'), 'messages');
    await page.getByRole('button', { name: 'Clear displayed samples' }).click();
    assert.equal(await page.locator('.card').count(), 0);
    assert.equal(await page.getByText('All caught up.', { exact: true }).count(), 1);
    await page.getByRole('button', { name: 'Reset demo' }).click();
    for (const width of [1440, 1024, 768, 390, 320]) {
      await page.setViewportSize({ width, height: 844 });
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false, `overflow at ${width}`);
    }
    assert.deepEqual(errors, []);
    console.log('PASS: preview interactions, empty states, privacy demo, ordering and five viewport widths');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
