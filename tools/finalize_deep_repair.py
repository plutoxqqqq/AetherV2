from pathlib import Path

repair = Path('tools/deep_public_source_repair.py')
text = repair.read_text()

old = "text = replace_once(text, \"\\tlocal ref = readfile('aetherv2/profiles/commit.txt')\\n\", \"\\tlocal ref = selectedSourceRef()\\n\", 'main fetch ref')"
new = "text = text.replace(\"\\tlocal ref = readfile('aetherv2/profiles/commit.txt')\\n\", \"\\tlocal ref = selectedSourceRef()\\n\", 1)"
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit('main fetch ref patch not found')

old_scan = "['SourceEndpoint', 'SourceToken', 'SourceRef']"
new_scan = "['license.SourceEndpoint', 'license.SourceToken', 'license.SourceRef', 'shared.AetherV2SourceEndpoint', 'shared.AetherV2SourceToken', 'shared.AetherV2SourceRef']"
if old_scan in text:
    text = text.replace(old_scan, new_scan, 1)
elif new_scan not in text:
    raise SystemExit('legacy scan patch not found')

append_marker = "# FINAL_DEEP_REPAIR_PATCHES"
if append_marker not in text:
    text += r'''

# FINAL_DEEP_REPAIR_PATCHES
# The loading screen refreshes its logo after the parallel asset fetch. Guard that second call too;
# some executors support the filesystem but do not expose a custom-asset registration function.
p = Path('init.lua')
t = p.read_text()
old = "\t\t\tlogo.Image = getcustomasset('aetherv2/assets/new/loading.png')"
new = "\t\t\tlogo.Image = safeLocalAsset('aetherv2/assets/new/loading.png')"
if old in t:
    t = t.replace(old, new, 1)
elif new not in t:
    raise SystemExit('late loading logo path not found')
p.write_text(t)

# The old regression explicitly required the deleted first-run release-channel branch. Assert the
# new current-public-ref and synchronous asset-healing invariants instead.
p = Path('backend/private-execution-regression.test.js')
t = p.read_text()
old = """test('the first authorized run publishes the exact source tree to main', () => {
  assert.match(initSource, /prefetchPaths = fetchFileList\\(initialRef\\)/);
  assert.match(initSource, /shared\\.AetherV2KnownSourceFiles = prefetchPaths/);
  assert.match(mainSource, /knownSourceFiles\\[repoPlacePath\\]/);
});"""
new = """test('public loader heals stale refs and publishes the current source tree', () => {
  assert.match(initSource, /shared\\.AetherV2PublicRef = commit/);
  assert.match(initSource, /fetchFileList\\(shared\\.AetherV2PublicRef or 'main'\\)/);
  assert.match(initSource, /verifySelectedAssets\\(prefetchPaths\\)/);
  assert.doesNotMatch(initSource, /selectedReleaseChannel|releasechannel\\.txt/);
  assert.match(initSource, /shared\\.AetherV2KnownSourceFiles = prefetchPaths/);
  assert.match(mainSource, /knownSourceFiles\\[repoPlacePath\\]/);
});"""
if old in t:
    t = t.replace(old, new, 1)
elif new not in t:
    raise SystemExit('source-tree regression block not found')
p.write_text(t)
'''

repair.write_text(text)
print('deep repair script finalized')
