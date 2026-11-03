# Loads data/restaurants.json and img/*.jpg into Supabase. Both stay local (gitignored).
# Usage: SUPABASE_SECRET_KEY=sb_secret_... python3 seed.py
# (Supabase → Project Settings → API Keys → secret key. Never commit it or put it in the page.)
import json, os, pathlib, urllib.request

URL = 'https://kbsgmtkftnurfjkhaxwl.supabase.co'
KEY = os.environ['SUPABASE_SECRET_KEY']
HDR = {'apikey': KEY} if KEY.startswith('sb_secret_') else {'apikey': KEY, 'Authorization': f'Bearer {KEY}'}
d = pathlib.Path(__file__).parent

def call(path, body, **headers):
    req = urllib.request.Request(URL + path, data=body, method='POST', headers={**HDR, **headers})
    return urllib.request.urlopen(req).status

rows = [{'id': r['id'], 'data': r} for r in json.loads((d / 'data/restaurants.json').read_text())]
call('/rest/v1/restaurants?on_conflict=id', json.dumps(rows).encode(),
     **{'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates'})
print(f'{len(rows)} restaurants loaded')

imgs = sorted((d / 'img').glob('*.jpg'))
for p in imgs:
    call(f'/storage/v1/object/restaurant-images/{p.name}', p.read_bytes(),
         **{'Content-Type': 'image/jpeg', 'x-upsert': 'true'})
print(f'{len(imgs)} photos uploaded')
