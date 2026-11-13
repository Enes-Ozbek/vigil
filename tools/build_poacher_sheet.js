// Renders the Poacher's procedural pixel rig to the PNGs the game loads.
//
//   node tools/build_poacher_sheet.js
//
// The rig (tools/poacher_rig/poacher-rig.js) draws every frame into a canvas,
// so it runs in a headless browser: needs Node and the `playwright` package
// with a Chromium build (npm i -g playwright && npx playwright install chromium).
//
// Writes:
//   assets/poacher.png        idle 12 / walk 8 / cast 8, one row each, 108x108
//   assets/poacher_arrow.png  the Bone Arrow projectile, pointing right
//
// It also prints the characters.gd values the rig measures (pivot, muzzle),
// so a change to the rig that moves the bow can be carried over by hand.

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '..');
const RIG = path.join(__dirname, 'poacher_rig', 'poacher-rig.js');

function png(dataUrl, out) {
  fs.writeFileSync(path.join(ROOT, out), Buffer.from(dataUrl.split(',')[1], 'base64'));
  console.log('wrote ' + out);
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.setContent('<html><body></body></html>');
  await page.addScriptTag({ content: fs.readFileSync(RIG, 'utf8') });
  const r = await page.evaluate(() => {
    const R = window.PoacherRig;
    return { sheet: R.sheetCanvas(1).toDataURL('image/png'), arrow: R.arrowURL(1), snippet: R.snippet() };
  });
  await browser.close();
  png(r.sheet, 'assets/poacher.png');
  png(r.arrow, 'assets/poacher_arrow.png');
  console.log('\ncharacters.gd values measured from the rig:\n' + r.snippet);
})();
