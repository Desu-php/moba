"""Read-only audit of already-extracted Warcraft object files; never runs JASS."""
from pathlib import Path
import argparse
import hashlib
import json
import struct

parser = argparse.ArgumentParser()
parser.add_argument('--reference', type=Path, default=Path('../map-reference'))
parser.add_argument('--output', type=Path, default=Path('docs/evidence/sasuke-source-records.json'))
args = parser.parse_args()
selected = set('Udea Uanb Eevi h01Y h01Q A02D A08K A03N A08G A01D ACbf A049 A00C A033 A0BF A01B A0L3 A02F A08H A0BD A06I A0HJ A0H4 A0GU A0GV A00Q A02G A045 A0HF A0HK A0HL A0HP A0F9 A0D3 A0HG A0HH A0HI A0OT A0NC A03S A0EO'.split())

def inspect(filename, extended):
    raw = (args.reference / filename).read_bytes()
    offset = 0
    def number(fmt='<i'):
        nonlocal offset
        value = struct.unpack_from(fmt, raw, offset)[0]
        offset += 4
        return value
    def four():
        nonlocal offset
        value = raw[offset:offset+4].decode('latin1')
        offset += 4
        return value
    def string():
        nonlocal offset
        end = raw.index(b'\0', offset)
        value = raw[offset:end]
        offset = end + 1
        try:
            return value.decode('utf-8')
        except UnicodeDecodeError:
            return value.decode('cp1251', errors='replace')
    version = number()
    records = []
    for table in ('original', 'custom'):
        for _ in range(number()):
            start = offset
            old, new = four(), four()
            modifications = []
            for _ in range(number()):
                field, kind = four(), number()
                level, data = (number(), number()) if extended else (0, 0)
                if kind == 0:
                    value = number()
                elif kind in (1, 2):
                    value = number('<f')
                elif kind == 3:
                    value = string()
                else:
                    raise ValueError(f'Unsupported field type {kind}')
                four()
                modifications.append(dict(field=field, type=kind, level=level, data=data, value=value))
            if old in selected or new in selected:
                records.append(dict(old=old, new=new, table=table, offset=start, modifications=modifications))
    assert offset == len(raw), (filename, offset, len(raw))
    return dict(file=filename, sha256=hashlib.sha256(raw).hexdigest(), version=version, records=records)

result = [inspect('war3map.w3a', True), inspect('war3map.w3u', False)]
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Audited {sum(len(section["records"]) for section in result)} source records')

