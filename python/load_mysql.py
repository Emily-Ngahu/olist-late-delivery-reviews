
from pathlib import Path

from db import connect_mysql

root = Path(__file__).resolve().parent.parent
script = root / "sql_mysql" / "01_load_local.sql"
if not script.exists():
    raise SystemExit("Run  python python/prepare_mysql_data.py  first.")

# drop comment lines, then split into statements (no semicolons appear inside any statement)
text = "\n".join(l for l in script.read_text(encoding="utf-8").splitlines() if not l.strip().startswith("--"))
statements = [s.strip() for s in text.split(";") if s.strip()]

conn = connect_mysql(database=None, local_infile=True)
cur = conn.cursor()
for stmt in statements:
    cur.execute(stmt)
    if stmt.upper().startswith("LOAD DATA"):
        table = stmt.split("INTO TABLE")[1].split()[0]
        print(f"loaded {table:<16} {cur.rowcount:>9,} rows")
    elif stmt.upper().startswith("SELECT"):
        print("\nRow counts:")
        for name, n in cur.fetchall():
            print(f"  {name:<16} {n:>9,}")
conn.commit()
conn.close()
