
import re
import warnings
from decimal import Decimal
from pathlib import Path

import pandas as pd

from db import connect_mysql

warnings.filterwarnings("ignore", message=".*pandas only supports SQLAlchemy.*")

root = Path(__file__).resolve().parent.parent
sql_text = (root / "sql_mysql" / "04_export.sql").read_text(encoding="utf-8")
out_dir = Path("dashboard")
out_dir.mkdir(exist_ok=True)

conn = connect_mysql()
# split the file into blocks that start with "-- file: name.csv"
blocks = re.split(r"^-- file:\s*(\S+)\s*$", sql_text, flags=re.M)[1:]
for name, query in zip(blocks[0::2], blocks[1::2]):
    query = "\n".join(l for l in query.splitlines() if not l.strip().startswith("--")).strip().rstrip(";")
    df = pd.read_sql(query, conn, coerce_float=False)
    for col in df.columns:                      # MySQL sums come back as exact decimals
        if df[col].dtype == object and isinstance(df[col].dropna().iloc[0], Decimal):
            num = pd.to_numeric(df[col].astype(float))
            df[col] = num.astype('int64') if (num % 1 == 0).all() else num
    df.to_csv(out_dir / name, index=False)
    print(f"{name:<30} {len(df):>5} rows")
conn.close()
