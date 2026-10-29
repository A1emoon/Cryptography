"""Independent Python pow / gcd references, including signed and huge inputs."""
from pathlib import Path
import random, math, json
rng = random.Random(20261015)
inputs = [(129,257,153), (113,512,-153), (0,16,0), (6,15,9), (-7,60,5)]
for digits in [2, 8, 25, 70, 120]:
    for _ in range(3):
        m = rng.randrange(10**(digits-1),10**digits)
        a = rng.randrange(-2*m, 2*m)
        n = rng.randrange(-3*m, 3*m)
        inputs.append((a,m,n))
inputs.extend([(113, 2**1024, 153), (2,10**1000+7,153), (-(10**1000+1),283,10**1000+3)])
result=[]
for a,m,n in inputs:
    inv = pow(a,-1,m) if math.gcd(a,m)==1 else None
    result.append(dict(a=str(a), m=str(m), n=str(n), inverse=None if inv is None else str(inv), result=None if inv is None else str(n*inv%m)))
path=Path(__file__).resolve().parents[1]/'Tests/NumberTheoryCoreTests/Fixtures/modular-references.json'
path.write_text(json.dumps(result,indent=2)+'\n')
print(len(result),'independent cases')
