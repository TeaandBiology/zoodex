import json
from pathlib import Path

p = Path('assets/data/species_catalog.json')
print('Reading', p)
raw = p.read_text(encoding='utf-8')
obj = json.loads(raw)

def strip_group_list(lst):
    for item in lst:
        if isinstance(item, dict) and 'group' in item:
            del item['group']

if isinstance(obj, list):
    strip_group_list(obj)
elif isinstance(obj, dict) and 'species' in obj and isinstance(obj['species'], list):
    strip_group_list(obj['species'])
else:
    raise SystemExit('Unexpected JSON structure')

p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding='utf-8')
print('Updated', p)
