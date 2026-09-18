'use strict';

const fs = require('node:fs');
const path = require('node:path');

// Every mutable file this backend owns lives in one directory, next to the code that writes it.
// The npm scripts run from backend/, so paths resolved against the process working directory are
// not stable: the older defaults were repository-relative strings that only lined up when the
// process happened to be launched from the repository root.
const DATA_DIR = path.join(__dirname, 'data');

// A deployment that predates the merged folder keeps writing to its existing file until it is
// moved by hand, so an upgrade can never start from a silently empty store. The first candidate
// that already exists wins; otherwise the new location is used and created on first write.
function dataPath(name, legacy = []) {
  const preferred = path.join(DATA_DIR, name);
  if (fs.existsSync(preferred)) return preferred;
  for (const candidate of legacy) {
    const absolute = path.isAbsolute(candidate) ? candidate : path.join(__dirname, candidate);
    if (absolute !== preferred && fs.existsSync(absolute)) return absolute;
  }
  return preferred;
}

module.exports = {DATA_DIR, dataPath};
