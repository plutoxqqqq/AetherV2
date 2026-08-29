from pathlib import Path

p = Path('tools/premium_backend_repair.py')
t = p.read_text()

old = "Path('backend/private-source.js').write_text(private_source)"
new = "private_source = private_source.replace(\\\"\\\\'use strict\\\\';\\\", \\\"'use strict';\\\", 1)\nPath('backend/private-source.js').write_text(private_source)"
if old in t:
    t = t.replace(old, new, 1)
elif new not in t:
    raise SystemExit('private-source writer not found')

old = "Path('backend/private-source.test.js').write_text(private_test)"
new = "private_test = private_test.replace(\\\"\\\\'use strict\\\\';\\\", \\\"'use strict';\\\", 1)\nPath('backend/private-source.test.js').write_text(private_test)"
if old in t:
    t = t.replace(old, new, 1)
elif new not in t:
    raise SystemExit('private-source test writer not found')

p.write_text(t)
print('premium backend generator finalized')
