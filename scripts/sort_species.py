import json
from pathlib import Path
p = Path(r"assets/data/species_catalog.json")
text = p.read_text(encoding="utf-8")
data = json.loads(text)
# Sort by scientific_name (case-insensitive), keeping items without the key last
data.sort(key=lambda x: (x.get("scientific_name") is None, (x.get("scientific_name") or "").lower()))
print(json.dumps(data, ensure_ascii=False, indent=2))
