/** Render the editable vector master. Requires Node.js and Sharp. */
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const source = path.join(root, 'App/Resources/AppIconSource.svg');
const destination = path.join(root, 'App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png');
(async () => {
  await sharp(source, { density: 288 }).resize(1024, 1024)
    .flatten({ background: '#071A32' }).removeAlpha().png().toFile(destination);
  const info = await sharp(destination).metadata();
  if (info.width !== 1024 || info.height !== 1024 || info.hasAlpha) throw new Error('Expected opaque 1024×1024 app icon');
  console.log(destination);
})().catch(error => { console.error(error); process.exitCode = 1; });
