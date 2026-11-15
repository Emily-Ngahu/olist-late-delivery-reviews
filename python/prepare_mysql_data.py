"""Prepare the Olist CSVs for loading into MySQL."""

from pathlib import Path

import pandas as pd


root = Path(__file__).resolve().parent.parent
src, out = root / "data", root / "data" / "mysql"
out.mkdir(parents=True, exist_ok=True)


def slim(name, cols, out_name=None):
    # read everything as text so dates, ids and blanks are copied exactly as they are
    df = pd.read_csv(src / f"{name}.csv", dtype=str, keep_default_na=False, usecols=cols)
    df = df[cols]
    df.to_csv(out / f"{out_name or name}.csv", index=False, lineterminator="\n")
    print(f"{(out_name or name):<36} {len(df):>9,} rows")


slim("olist_orders_dataset", ["order_id", "customer_id", "order_status", "order_purchase_timestamp",
                              "order_delivered_customer_date", "order_estimated_delivery_date"], "orders")
slim("olist_order_items_dataset", ["order_id", "order_item_id", "product_id", "seller_id", "price",
                                   "freight_value"], "order_items")
slim("olist_order_reviews_dataset", ["review_id", "order_id", "review_score"], "order_reviews")
slim("olist_customers_dataset", ["customer_id", "customer_zip_code_prefix", "customer_state"], "customers")
slim("olist_sellers_dataset", ["seller_id", "seller_zip_code_prefix", "seller_state"], "sellers")
slim("olist_products_dataset", ["product_id", "product_category_name"], "products")
slim("product_category_name_translation", ["product_category_name", "product_category_name_english"],
     "category_names")

# geolocation: one average point per zip prefix (what the distance calculation uses)
geo = pd.read_csv(src / "olist_geolocation_dataset.csv",
                  usecols=["geolocation_zip_code_prefix", "geolocation_lat", "geolocation_lng"])
cent = (geo.groupby("geolocation_zip_code_prefix", as_index=False)
           .agg(lat=("geolocation_lat", "mean"), lng=("geolocation_lng", "mean"))
           .rename(columns={"geolocation_zip_code_prefix": "zip_prefix"}))
cent.to_csv(out / "zip_centroids.csv", index=False, lineterminator="\n")
print(f"{'zip_centroids':<36} {len(cent):>9,} rows")

template = (root / "sql_mysql" / "01_load.sql").read_text(encoding="utf-8")
local = template.replace("DATA_DIR", out.as_posix())
(root / "sql_mysql" / "01_load_local.sql").write_text(local, encoding="utf-8")
print("\nWrote sql_mysql/01_load_local.sql with this folder path:", out.as_posix())
