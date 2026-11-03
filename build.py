# Inlines data/restaurants.json into template.html → index.html. Run after editing either.
import json, pathlib
d = pathlib.Path(__file__).parent
data = json.dumps(json.loads((d / 'data/restaurants.json').read_text()), ensure_ascii=False, separators=(',', ':'))
(d / 'index.html').write_text((d / 'template.html').read_text().replace('/*DATA*/[]', data))
