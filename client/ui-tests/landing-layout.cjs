const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

(async () => {
  const browser = await chromium.launch({ headless: true, channel: 'chrome' });
  try {
    for (const [width, height] of [[1024, 500], [320, 568], [390, 844], [844, 390]]) {
      const page = await browser.newPage({ viewport: { width, height } });
      await page.goto(process.env.UI_TEST_ORIGIN || 'http://127.0.0.1:5173');
      await page.evaluate(() => document.fonts.ready);
      await page.waitForFunction(() => [...document.images].every(image => image.complete && image.naturalWidth > 0));
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
      const copy = await page.locator('.landing-copy').boundingBox();
      const friend = await page.locator('.landing-reaction-friend').boundingBox();
      const crush = await page.locator('.landing-reaction-crush').boundingBox();
      if (width === 1024) {
        assert.equal(copy.x, 90);
        assert.equal(copy.y, 90);
        assert(Math.abs(friend.x - 620) < 1 && Math.abs(friend.y - 102.26) < 1);
        assert(Math.abs(crush.x - 620.44) < 1 && Math.abs(crush.y - 188.41) < 1);
      }
      for (const reaction of await page.locator('.landing-reaction').all()) {
        const rect = await reaction.boundingBox();
        assert(rect.x >= 0 && rect.x + rect.width <= width, 'Rotated card stays inside the screen');
      }
      if (process.env.UI_SCREENSHOT_DIR) await page.screenshot({ path: `${process.env.UI_SCREENSHOT_DIR}/landing-${width}x${height}.png`, fullPage: true });
      await page.close();
      console.log(`Landing passed at ${width}x${height}`);
    }
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
