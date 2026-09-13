"""Verify the committed social textures and approved QR source hashes."""
from pathlib import Path
import hashlib
import json
import struct

root=Path(__file__).resolve().parents[2]
records=json.loads((root/'assets/about/textures.json').read_text())
assert len(records)==7
for record in records:
    p=root/record['file'];data=p.read_bytes()
    assert hashlib.sha256(data).hexdigest()==record['sha256'],p
    assert data[2]==2 and data[16]==32,'uncompressed RGBA TGA required'
    assert list(struct.unpack_from('<HH',data,12))==record['size']
    if 'sourceSha256' in record:
        source=root/'assets/about'/(p.stem+'-v1.png')
        assert hashlib.sha256(source.read_bytes()).hexdigest()==record['sourceSha256']
prompts=json.loads((root/'assets/about/imagegen-prompts.json').read_text())
assert prompts['support'] and prompts['contact'] and 'confirmed both' in prompts['approved']
print('Social textures PASS: five icons, two approved-source code textures, dimensions, format and SHA-256')
