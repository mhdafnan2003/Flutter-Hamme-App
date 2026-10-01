// Run against Vite: PLAYWRIGHT_MODULE can point to an installed Playwright package.
// API responses are intercepted; this never submits a real vote.
const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const origin = process.env.UI_TEST_ORIGIN || 'http://127.0.0.1:5173';
const screenshotDir = process.env.UI_SCREENSHOT_DIR;

(async () => {
  const browser = await chromium.launch({ headless: true, channel: 'chrome' });
  try {
    for (const [width, height] of [[360, 800], [320, 568], [390, 844], [844, 390]]) {
      const page = await browser.newPage({ viewport: { width, height } });
      await page.route('**/public-profile/**', route => route.fulfill({
        json: { user: { name: 'Sneha', profileImageUrl: `${origin}/tic.png` } },
      }));
      await page.route('**/anonymous-response', route => route.fulfill({ json: {} }));
      await page.goto(`${origin}/poll/layout-review`);
      await page.getByRole('button', { name: /Friend$/ }).waitFor();
      await page.evaluate(() => document.fonts.ready);
      await page.waitForFunction(() => [...document.images].every(image => image.complete && image.naturalWidth > 0));
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
      const reactions = page.getByRole('button').filter({ hasText: /Friend|Crush|Frenemy/ });
      assert.equal(await reactions.count(), 3);
      for (const button of await reactions.all()) {
        const rect = await button.boundingBox();
        assert(rect.width > 180 && rect.height >= 44, 'Reaction remains usable at narrow widths');
        assert(rect.x >= 0 && rect.x + rect.width <= width);
      }
      if (width === 360 && height === 800) {
        const friend = await page.getByRole('button', { name: /Friend$/ }).boundingBox();
        assert(Math.abs(friend.x - 50) < 1 && Math.abs(friend.y - 298) < 1);
        assert.equal(friend.width, 260);
        assert.equal(await page.getByRole('button', { name: /Friend$/ }).evaluate(n => getComputedStyle(n).fontSize), '18px');
      }
      if (screenshotDir) await page.screenshot({ path: `${screenshotDir}/question-${width}x${height}.png`, fullPage: true });
      await page.getByRole('button', { name: /Friend$/ }).click();
      const reveal = page.getByRole('button', { name: 'Reveal' });
      await reveal.waitFor();
      await page.waitForFunction(() => [...document.images].every(image => image.complete && image.naturalWidth > 0));
      const geometry = await reveal.evaluate(button => {
        const r = button.getBoundingClientRect();
        const label = button.querySelector('span').getBoundingClientRect();
        const arrow = button.querySelector(':scope > img').getBoundingClientRect();
        return {
          button: { x: r.x, y: r.y, width: r.width, height: r.height },
          labelCenter: label.x + label.width / 2,
          arrowRight: arrow.right,
          labelPosition: getComputedStyle(button.querySelector('span')).position,
          arrowPosition: getComputedStyle(button.querySelector(':scope > img')).position,
          shadow: getComputedStyle(button).boxShadow,
        };
      });
      assert.equal(geometry.labelPosition, 'absolute');
      assert.equal(geometry.arrowPosition, 'absolute');
      assert(Math.abs(geometry.labelCenter - (geometry.button.x + geometry.button.width / 2 - 10)) < 1);
      assert(Math.abs(geometry.arrowRight - (geometry.button.x + geometry.button.width - 24)) < 1);
      assert(geometry.shadow.includes('6px'), 'Raised base remains outside the glaze clipping box');
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
      if (screenshotDir) await page.screenshot({ path: `${screenshotDir}/reveal-${width}x${height}.png`, fullPage: true });
      await reveal.scrollIntoViewIfNeeded();
      assert(await reveal.isVisible());
      await page.close();
      console.log(`Question and Reveal passed at ${width}x${height}`);
    }
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
