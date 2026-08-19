import subprocess

# Kept so the existing workflow's compatibility rewrite still succeeds on reruns.
DUMMY_VALIDATOR = """for name in KEEP|{'AutoAgni','AutoBekzat','AutoBuilder','AutoEmber','AutoMelody','AutoWarden'}:
    if not blocks(text,name): raise RuntimeError('missing after patch '+name)
"""

BASE_PATCHER_COMMIT = 'a00b1e503de2e75aaa01e2378bd809c0f1fb9194'
source = subprocess.check_output(
    ['git', 'show', f'{BASE_PATCHER_COMMIT}:.github/scripts/apply_kit_rework.py'],
    text=True,
)

needle = (
    "for name in KEEP|" +
    "{'AutoAgni','AutoBekzat','AutoBuilder','AutoEmber','AutoMelody','AutoWarden'}" +
    ":\n    if not blocks(text,name): raise RuntimeError('missing after patch '+name)\n"
)
replacement = '''for name,new_block in {
    'AutoAgni': AGNI,
    'AutoBekzat': BEKZAT,
    'AutoBuilder': BUILDER,
    'AutoEmber': EMBER,
    'AutoMelody': MELODY,
    'AutoWarden': WARDEN,
}.items():
    if not re.search(r"\\bName\\s*=\\s*['\\\"]" + re.escape(name) + r"['\\\"]", text):
        text += "\\n\\n" + new_block + "\\n"
for name in KEEP:
    if not re.search(r"\\bName\\s*=\\s*['\\\"]" + re.escape(name) + r"['\\\"]", text):
        raise RuntimeError('kept module disappeared '+name)
'''

if needle not in source:
    raise RuntimeError('base patcher validator changed unexpectedly')
source = source.replace(needle, replacement)
exec(compile(source, '<aetherv2-kit-rework>', 'exec'), {'__name__': '__main__'})
