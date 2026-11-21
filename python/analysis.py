"""Does late delivery drive bad reviews, once we control for other things?

Reads the order_facts table from the MySQL database "olist", fits a logistic regression,
and prints/saves the numbers used in the README and dashboard.
"""
import warnings
from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.formula.api as smf

from db import connect_mysql

Path("dashboard").mkdir(exist_ok=True)
warnings.filterwarnings("ignore", message=".*pandas only supports SQLAlchemy.*")
df = pd.read_sql("SELECT * FROM order_facts", connect_mysql())

# MySQL returns exact decimals; turn everything the model needs into plain numbers
for col in ["item_value", "freight_value", "freight_ratio", "review_score", "distance_km",
            "days_vs_estimate", "days_to_deliver", "is_late", "is_bad_review"]:
    df[col] = pd.to_numeric(df[col].astype(float))
print(f"{len(df):,} delivered single-seller orders")

# Prepare the columns 
df["delay_band"] = pd.cut(
    df["days_vs_estimate"], bins=[-1e9, 0, 3, 7, 1e9],
    labels=["on_time", "late_1_3", "late_4_7", "late_8_plus"])
df["is_bad_review"] = df["is_bad_review"].astype(int)
df["log_distance"] = np.log1p(df["distance_km"])

# keep the 15 biggest categories, lump the rest, so the model stays readable
top = df["category"].value_counts().head(15).index
df["category_grp"] = np.where(df["category"].isin(top), df["category"], "other")
df = df.dropna(subset=["log_distance", "freight_ratio"])
print(f"{len(df):,} orders after dropping missing distance/freight")

# 1. Plain comparison 
print("\nBad-review rate by delay band:")
print(df.groupby("delay_band", observed=True)["is_bad_review"].agg(["mean", "size"]).round(3))

# 2. Logistic regression: does lateness matter after controls?
formula = ("is_bad_review ~ C(delay_band, Treatment('on_time')) + log_distance + freight_ratio "
           "+ np.log1p(item_value) + C(category_grp) + C(customer_state)")
model = smf.logit(formula, data=df).fit(disp=False)
or_table = pd.DataFrame({"odds_ratio": np.exp(model.params),
                         "ci_low": np.exp(model.conf_int()[0]),
                         "ci_high": np.exp(model.conf_int()[1]),
                         "p_value": model.pvalues}).round(3)
delay_rows = or_table[or_table.index.str.contains("delay_band")]
print("\nOdds ratios for delay (vs on time), controlling for distance, freight, price, category, state:")
print(delay_rows)
or_table.to_csv("dashboard/model_odds_ratios.csv", index_label="term")

# 3. Counterfactual: how many bad reviews would on-time delivery have avoided?
late = df[df["delay_band"] != "on_time"].copy()
p_actual = model.predict(late)
cf = late.copy()
cf["delay_band"] = "on_time"
p_cf = model.predict(cf)
avoided = float((p_actual - p_cf).sum())
total_bad = int(df["is_bad_review"].sum())
print(f"\nEstimated bad reviews avoidable if every late order had arrived on time: "
      f"{avoided:,.0f} of {total_bad:,} ({avoided / total_bad:.1%})")

summary = pd.DataFrame({
    "metric": ["delivered_orders", "bad_reviews", "estimated_avoidable_bad_reviews", "avoidable_share"],
    "value": [len(df), total_bad, round(avoided), round(avoided / total_bad, 3)]})
summary.to_csv("dashboard/headline_numbers.csv", index=False)
print("\nSaved dashboard/model_odds_ratios.csv and dashboard/headline_numbers.csv")
