import json
from pathlib import Path
from datetime import date

root = Path(__file__).resolve().parents[1]
zoos_file = root / 'assets' / 'data' / 'zoos.json'
inv_dir = root / 'assets' / 'data' / 'inventories'

with zoos_file.open('r', encoding='utf-8') as f:
    zoos = json.load(f)

created = []
for z in zoos:
    zoo_id = z.get('id')
    if not zoo_id:
        continue
    out = inv_dir / f'{zoo_id}.json'
    if out.exists():
        continue
    data = {
        'zoo_id': zoo_id,
        'last_updated': date.today().isoformat(),
        'items': []
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open('w', encoding='utf-8') as wf:
        json.dump(data, wf, indent=2, ensure_ascii=False)
    created.append(str(out.relative_to(root)))

print('Created', len(created), 'inventory files:')
for p in created:
    print(p)
