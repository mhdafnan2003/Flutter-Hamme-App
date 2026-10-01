// Run against Vite: PLAYWRIGHT_MODULE can point to an installed Playwright package.
// API responses are intercepted; this never submits a real vote.
const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const origin = process.env.UI_TEST_ORIGIN || 'http://127.0.0.1:5173';
const screenshotDir = process.env.UI_SCREENSHOT_DIR;

(async () => {
  const browser = await chromium.launch({ headless: true, channel: 'chrome' });
  try {
    for (const [width, height, profileName = 'Sneha'] of [[360, 800], [320, 568], [390, 844], [844, 390], [320, 568, 'AveryVeryLongUnbrokenDisplayName']]) {
      const page = await browser.newPage({ viewport: { width, height } });
      await page.clock.install();
      await page.route('**/public-profile/**', route => route.fulfill({
        json: { user: { name: profileName, profileImageUrl: `${origin}/tic.png` } },
      }));
      await page.route('**/anonymous-response', route => route.fulfill({ json: {} }));
      await page.goto(`${origin}/poll/layout-review`);
      await page.getByRole('button', { name: /Friend$/ }).waitFor();
      await page.evaluate(() => document.fonts.ready);
      await page.evaluate(() => document.fonts.load('800 18px Nunito'));
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
      const screenshotName = `${width}x${height}${profileName === 'Sneha' ? '' : '-long-name'}`;
      if (screenshotDir) await page.screenshot({ path: `${screenshotDir}/question-${screenshotName}.png`, fullPage: true });
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
      const friends = await page.locator('.friends-playing').boundingBox();
      assert(friends.y >= geometry.button.y + geometry.button.height + 20, 'Extra footer clears the raised CTA');
      if (width === 360 && height === 800) {
        assert.equal(geometry.button.y, 416);
        assert.equal(geometry.button.width, 328);
        assert.equal(geometry.button.height, 56);
      }
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
      if (screenshotDir) await page.screenshot({ path: `${screenshotDir}/reveal-${screenshotName}.png`, fullPage: true });
      await reveal.scrollIntoViewIfNeeded();
      assert(await reveal.isVisible());
      await page.clock.runFor(31000);
      assert(await reveal.isDisabled(), 'Expiration keeps Reveal disabled');
      const expiredLabel = page.getByText('LINK EXPIRED', { exact: true });
      assert(await expiredLabel.isVisible());
      assert.equal(await expiredLabel.evaluate(n => getComputedStyle(n).color), 'rgb(255, 87, 87)');
      assert.equal(await page.getByText('00s', { exact: true }).evaluate(n => getComputedStyle(n).color), 'rgb(255, 87, 87)');
      assert.equal(await reveal.evaluate(n => getComputedStyle(n).opacity), '0.4');
      assert.equal(await reveal.evaluate(n => getComputedStyle(n, '::after').animationName), 'none');
      if (screenshotDir) await page.screenshot({ path: `${screenshotDir}/reveal-expired-${screenshotName}.png`, fullPage: true });
      await page.close();
      console.log(`Question and Reveal passed at ${width}x${height}`);
    }
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
