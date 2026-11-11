import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const release = JSON.parse(fs.readFileSync(path.join(root, 'release.json'), 'utf8'));
// An optional package root lets the same preservation check inspect the built ZIP.
const packageRoot = process.argv[2] ? path.resolve(process.argv[2]) : root;
const modRoot = path.join(packageRoot, 'workshop/Contents/mods', release.modId);
const read = p => fs.readFileSync(p, 'utf8');
const hash = p => createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const walk = dir => fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
  const p = path.join(dir, entry.name);
  assert(!entry.isSymbolicLink(), `Unexpected symlink: ${p}`);
  return entry.isDirectory() ? walk(p) : [p];
});
const properties = file => Object.fromEntries(read(file).split(/\r?\n/)
  .filter(line => line.includes('=')).map(line => {
    const i = line.indexOf('=');
    return [line.slice(0, i), line.slice(i + 1)];
  }));

assert.match(release.version, /^\d+\.\d+\.\d+$/);
assert.equal(release.modId, 'DoomedRoadkillPhysics');
assert.equal(release.workshopId, '3776615501');
assert.equal(release.distribution, 'steam-workshop-lua-only');
assert.deepEqual(release.projectZomboid.profiles.map(p => p.folder), ['42', '42.21', '42.22']);
assert.deepEqual(fs.readdirSync(modRoot, { withFileTypes: true })
  .filter(entry => entry.isDirectory()).map(entry => entry.name).sort(),
['42', '42.21', '42.22', 'common'], 'Unexpected profile directory');
let preservedFiles = 0;
for (const [version, folders] of [['1.0.0', ['42', 'common']], ['1.1.0', ['42.21']]]) {
  const fixture = JSON.parse(read(path.join(root, `tests/fixtures/legacy-${version}.json`)));
  const files = folders.flatMap(folder => walk(path.join(modRoot, folder)))
    .map(p => path.relative(modRoot, p)).sort();
  assert.deepEqual(files, Object.keys(fixture.paths).sort(), `Legacy ${version} file list changed`);
  for (const file of files) {
    assert.equal(hash(path.join(modRoot, file)), fixture.paths[file], `Legacy file changed: ${file}`);
  }
  preservedFiles += files.length;
}
assert.equal(hash(path.join(packageRoot, 'release.json')), hash(path.join(root, 'release.json')),
  'Packaged release metadata differs from source');

for (const profile of release.projectZomboid.profiles) {
  const dir = path.join(modRoot, profile.folder);
  const info = properties(path.join(dir, 'mod.info'));
  assert.equal(info.id, release.modId);
  assert.equal(info.modversion, profile.modVersion);
  assert.equal(info.versionMin, profile.versionMin);
  assert.equal(info.versionMax, profile.versionMax);
  if (profile.folder === '42.22') {
    assert.equal(profile.runtimeVersionPolicy, 'major-minor');
    assert.equal(info.versionMin, profile.folder, 'Minimum must use major/minor only');
    assert.equal(info.versionMax, profile.folder, 'Maximum must lock the same major/minor');
  }
  assert(profile.auditedBuilds.length > 0);
  for (const build of profile.auditedBuilds) {
    assert.match(build.jarSha256, /^[a-f0-9]{64}$/);
    assert.match(build.steamBuildId, /^\d+$/);
  }
  const client = read(path.join(dir, 'media/lua/client/DoomedRoadkillPhysics_Client.lua'));
  const core = read(path.join(dir, 'media/lua/shared/DoomedRoadkillPhysics_Core.lua'));
  assert(core.includes(`Core.MOD_VERSION = "${profile.modVersion}"`));
  assert(!client.includes('vehicles:get('), 'Vehicle collection must use its Set iterator');
  assert(!client.includes('vehicle:testCollisionWithProneCharacter'), 'Prone test rewrites wheel impulses');
  JSON.parse(read(path.join(dir, 'media/lua/shared/Translate/EN/Sandbox.json')));
}

// Sandbox names/defaults and assets are identical in the new profile, preserving saves.
for (const file of ['media/sandbox-options.txt', 'media/lua/shared/Translate/EN/Sandbox.json', 'poster.png']) {
  for (const profile of release.projectZomboid.profiles.slice(1)) {
    assert.equal(hash(path.join(modRoot, '42', file)), hash(path.join(modRoot, profile.folder, file)),
      `${profile.folder}/${file}`);
  }
}
const workshop = properties(path.join(packageRoot, 'workshop/workshop.txt'));
assert.equal(workshop.id, release.workshopId, 'Updates must target the existing Workshop item');
assert.equal(workshop.visibility, 'public', 'Preserve the existing public visibility');
for (const file of walk(path.join(packageRoot, 'workshop'))) {
  assert(!/\.(java|jar|class)$/i.test(file), `Java file in Workshop package: ${file}`);
}
for (const file of [
  'README.md', 'CHANGELOG.md', 'LICENSE.md', 'docs/physics-notes.md',
  'docs/compatibility-42.21.md', 'docs/compatibility-42.22.2.md', 'docs/test-matrix.md', 'docs/multiplayer.md',
  `docs/release-notes-${release.version}.md`, 'docs/steam-workshop-release.md',
]) assert(fs.statSync(path.join(packageRoot, file)).isFile(), `Missing ${file}`);

console.log(`Package metadata verified; ${preservedFiles} files across 42/, 42.21/, and common/ preserved byte-for-byte.`);
