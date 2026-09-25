"""Offline artifact checks; does not execute notebooks or query PostgreSQL."""
import ast
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def rows(path):
    with (ROOT / path).open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def main():
    notebooks = sorted((ROOT / "notebooks").glob("*.ipynb"))
    assert len(notebooks) == 3
    code_cells = 0
    for path in notebooks:
        notebook = json.loads(path.read_text(encoding="utf-8"))
        for index, cell in enumerate(notebook["cells"]):
            if cell["cell_type"] == "code":
                ast.parse("".join(cell["source"]), filename=f"{path.name}:cell {index}")
                assert not any(o.get("output_type") == "error" for o in cell.get("outputs", [])), path.name
                code_cells += 1
    raw = rows("data/raw/WA_Fn-UseC_-Telco-Customer-Churn.csv")
    assert len(raw) == 7043
    assert len({r["customerID"] for r in raw}) == len(raw)
    funnel = rows("powerbi/data/conversion_funnel.csv")
    assert [int(r["stage_order"]) for r in funnel] == [1, 2, 3, 4]
    counts = [int(r["users"]) for r in funnel]
    assert counts == sorted(counts, reverse=True)
    assert counts[2] == len(raw)
    assert counts[3] == sum(r["Churn"] == "No" for r in raw)
    monthly = rows("powerbi/data/monthly_kpis.csv")
    months = [r["month"] for r in monthly]
    assert months == sorted(set(months))
    for r in monthly:
        assert int(r["mau"]) >= 0
        if r["mrr"]:
            assert float(r["mrr"]) >= 0
        if r["churn_rate_pct"]:
            assert 0 <= float(r["churn_rate_pct"]) <= 100
    for r in rows("powerbi/data/cohort_retention.csv"):
        assert 0 <= float(r["retention_pct"]) <= 100
    json.loads((ROOT / "powerbi/theme.json").read_text(encoding="utf-8"))
    print(f"PASS: {len(notebooks)} notebooks, {code_cells} code cells, source IDs, saved KPI/funnel/cohort checks, theme JSON")
    print("Not checked: dependency installation, live SQL, notebook execution, Power BI rendering.")


if __name__ == "__main__":
    main()
