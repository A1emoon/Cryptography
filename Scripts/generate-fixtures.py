"""Independent exact reference values. Python's integers do not use the Swift algorithm."""
import json
import random
from pathlib import Path

rng = random.Random(78100273)
rows = []
for digits in (1, 9, 19, 40, 100, 300):
    for _ in range(20):
        a = rng.randrange(10 ** (digits - 1), 10 ** digits)
        b = rng.randrange(10 ** (digits - 1), 10 ** digits)
        m = rng.randrange(1, 10 ** digits)
        a *= rng.choice((-1, 1))
        b *= rng.choice((-1, 1))
        rows.append(dict(a=str(a), b=str(b), m=str(m), answer=str((a * b) % m)))
for a, b, m in ((2**64, 2**64 + 1, 2**64 - 1), (10**1000 + 12345, 1, 273),
                 (8, 10**500 + 16, 97), (-273, 2, 273), (-7, -9, 13)):
    rows.append(dict(a=str(a), b=str(b), m=str(m), answer=str((a * b) % m)))
destination = Path(__file__).resolve().parents[1] / 'Tests/NumberTheoryCoreTests/Fixtures/python-references.json'
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(rows, indent=2) + '\n')
print(f'{len(rows)} independent reference cases')
