#!/usr/bin/env python3
from pathlib import Path

path = Path(__file__).resolve().parents[1] / 'backend' / 'private-execution-regression.test.js'
source = path.read_text(encoding='utf-8')
old = "  assert.match(initWrapper, /event\\s*=\\s*'heartbeat'/);"
new = "  assert.match(initWrapper, /event\\s*=\\s*eventName\\s*or\\s*'heartbeat'|sendTelemetry\\(sessionId,\\s*'heartbeat'\\)/);\n  assert.match(initWrapper, /sendTelemetry\\(sessionId,\\s*'session_end'\\)/);"
if new not in source:
    if old not in source:
        raise SystemExit('heartbeat regression marker missing')
    path.write_text(source.replace(old, new, 1), encoding='utf-8')
    print('Updated telemetry wrapper regression')
else:
    print('Telemetry wrapper regression already current')
