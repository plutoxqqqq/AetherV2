from pathlib import Path

# The registry moved its dedicated data branch to AETHER_REGISTRY_BRANCH long ago. The old test
# still set GITHUB_BRANCH, so it accidentally pointed the registry at its default branch and its
# mocked requests no longer matched the intended configuration.
registry_test = Path('backend/key-registry.test.js')
text = registry_test.read_text()
old = "process.env.GITHUB_BRANCH = 'release/security';"
new = "process.env.AETHER_REGISTRY_BRANCH = 'release/security';"
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit('key registry branch test setting not found')
registry_test.write_text(text)

# These two tests described the retired key-gated normal-source backend. Replace them with the
# guarantees the premium-only backend now needs to preserve.
regression = Path('backend/private-execution-regression.test.js')
text = regression.read_text()
old = """test('authenticated source requests use the in-memory session instead of rereading the registry', () => {
  const requireSessionBody = sourceServer.match(/const requireSession = url => \\{([\\s\\S]*?)\\n\\};/);
  assert.ok(requireSessionBody);
  assert.equal(requireSessionBody[1].includes('isKeyIdActive'), false);
  assert.match(sourceServer, /invalidateMutation\\('revokeKey'/);
  assert.match(sourceServer, /invalidateMutation\\('unlinkKey'/);
  assert.match(sourceServer, /invalidateMutation\\('rotateKey'/);
});

test('private source still supports large BedWars files and bounded downgrade history', () => {
  assert.match(sourceServer, /git\\/blobs\\//);
  assert.match(sourceServer, /url\\.pathname === '\\/history'/);
  assert.match(sourceServer, /requestedLimit = 11/);
});"""
new = """test('premium source requests revalidate live key state and Roblox binding', () => {
  assert.match(sourceServer, /const requireSession = async value =>/);
  assert.match(sourceServer, /registry\\.getKeyInfo\\(session\\.keyId\\)/);
  assert.match(sourceServer, /info\\.status !== 'active'/);
  assert.match(sourceServer, /binding\\.username\\.toLowerCase\\(\\) !== session\\.username\\.toLowerCase\\(\\)/);
  assert.match(sourceServer, /String\\(binding\\.userId\\) !== session\\.userId/);
  assert.match(sourceServer, /revoked, expired, rotated, or unlinked/);
});

test('Render serves premium only and retired normal-source routes stay removed', () => {
  for (const route of ['/loader', '/authorize', '/source', '/commit', '/history', '/tree']) {
    assert.equal(sourceServer.includes(\"url.pathname === '\" + route + \"'\"), false, `retired route still present: ${route}`);
  }
  assert.match(sourceServer, /url\\.pathname === '\\/premium\\/authorize'/);
  assert.match(sourceServer, /url\\.pathname === '\\/premium\\/source'/);
  assert.match(sourceServer, /url\\.pathname === '\\/premium\\/tree'/);
  assert.match(sourceServer, /premiumGithub\\('contents\\/'/);
  assert.match(sourceServer, /premiumGithub\\('git\\/trees\\/'/);
  assert.doesNotMatch(sourceServer, /requestedLimit = 11|git\\/blobs\\//);
});"""
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit('retired private-source regression blocks not found')
regression.write_text(text)

print('premium-only regression tests finalized')
