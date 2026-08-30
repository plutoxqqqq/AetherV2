#!/usr/bin/env python3
# Workflow helper: upgrades the one-time splitter before the large source migration runs.
from pathlib import Path

path = Path(__file__).with_name('apply-bedwars-refactor.py')
text = path.read_text(encoding='utf-8')

old = '''    # A module belongs to the nearest run(function()) wrapper around it. That keeps helper locals,
    # toggles, callbacks, and conditional alternatives in the same source block without inventing
    # a new runtime scope.
    nearest = {}
    for call_index, call in enumerate(calls):
        containing = [span for span in spans if span[0] <= call['pos'] < span[1]]
        if not containing:
            raise RuntimeError(f"Module {call['name']} is not inside run(function())")
        nearest[call_index] = min(containing, key=lambda span: span[1] - span[0])

    selected = sorted(set(nearest.values()))
'''

new = '''    # Prefer the nearest run(function()) wrapper because it keeps helper locals, settings,
    # callbacks, and conditional alternatives together. A few legacy modules are registered
    # directly rather than through run(); for those, extract the balanced CreateModule call
    # itself instead of refusing the entire refactor.
    def standalone_module_span(call):
        match = MODULE_CALL.match(masked, call['pos'])
        if not match:
            raise RuntimeError(f"Could not re-read module constructor for {call['name']}")
        opening = match.end() - 1
        depth = 0
        end = None
        for index in range(opening, len(masked)):
            char = masked[index]
            if char == '(':
                depth += 1
            elif char == ')':
                depth -= 1
                if depth == 0:
                    end = index + 1
                    break
        if end is None:
            raise RuntimeError(f"Unclosed standalone CreateModule call for {call['name']}")
        while end < len(source) and source[end] in ' \\t':
            end += 1
        if end < len(source) and source[end] == ';':
            end += 1

        # Include a simple `Module =` / `local Module =` prefix when it is on the same line.
        # More complex surrounding control flow remains in main.lua and the marker is restored
        # at exactly the old constructor position when bundle.lua is generated.
        line_start = source.rfind('\\n', 0, call['pos']) + 1
        prefix = source[line_start:call['pos']]
        start = line_start if re.fullmatch(r'\\s*(?:local\\s+)?[A-Za-z_][A-Za-z0-9_, \\t]*=\\s*', prefix) else call['pos']
        return (start, end)

    nearest = {}
    standalone_count = 0
    for call_index, call in enumerate(calls):
        containing = [span for span in spans if span[0] <= call['pos'] < span[1]]
        if containing:
            nearest[call_index] = min(containing, key=lambda span: span[1] - span[0])
        else:
            nearest[call_index] = standalone_module_span(call)
            standalone_count += 1

    selected = sorted(set(nearest.values()))
    if standalone_count:
        print(f'Found {standalone_count} module registration(s) outside run(function()); extracting their constructors directly')
'''

if old not in text:
    if new in text:
        print('Standalone module support is already applied')
    else:
        raise SystemExit('Expected splitter block was not found')
else:
    path.write_text(text.replace(old, new, 1), encoding='utf-8')
    print('Patched splitter to handle standalone CreateModule calls')
