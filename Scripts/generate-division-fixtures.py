"""Independent Euclidean division references using Python divmod."""
import json
import random
from pathlib import Path

rng = random.Random(1530041)
cases = [(1530, 41), (13, 7), (0, 3), (3, 7), (41, 41),
         (10**1000 + 1530, 41), (10**500 - 1, 1), (2**1024, 2**512)]
for digits in (1, 10, 20, 50, 100, 300):
    for _ in range(20):
        a = rng.randrange(10**(digits-1), 10**digits) * rng.choice((-1, 1))
        divisor_digits = rng.randint(1, digits)
        b = rng.randrange(10**(divisor_digits-1), 10**divisor_digits) * rng.choice((-1, 1))
        cases.append((a, b))
rows = []
for a, b in cases:
    q, r = divmod(a, abs(b))
    q = q if b > 0 else -q
    assert a == b*q+r and 0 <= r < abs(b)
    rows.append(dict(a=str(a), b=str(b), q=str(q), r=str(r)))
destination = Path(__file__).resolve().parents[1] / 'Tests/NumberTheoryCoreTests/Fixtures/division-references.json'
destination.write_text(json.dumps(rows, indent=2) + '\n')
print(f'{len(rows)} independent division references')
