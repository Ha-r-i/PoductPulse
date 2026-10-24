"""Offline artifact checks; does not execute notebooks or query PostgreSQL."""
import ast
import csv
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def rows(path):
    with (ROOT / path).open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def validate_report():
    report_path = ROOT / "powerbi/ProductPulse_Updated.pbix"
    expected = {"Executive Overview", "User Behaviour", "Retention", "Conversion Funnel"}
    columns = {
        path.stem: set(rows(path.relative_to(ROOT))[0])
        for path in (ROOT / "powerbi/data").glob("*.csv")
    }

    def check_fields(value):
        if isinstance(value, dict):
            if "Column" in value:
                field = value["Column"]
                table = field.get("Expression", {}).get("SourceRef", {}).get("Entity")
                if table:
                    assert table in columns, f"Unknown report table: {table}"
                    assert field["Property"] in columns[table], f"Unknown column: {table}.{field['Property']}"
            for child in value.values():
                check_fields(child)
        elif isinstance(value, list):
            for child in value:
                check_fields(child)

    with zipfile.ZipFile(report_path) as archive:
        assert archive.testzip() is None, "Corrupt report archive"
        assert "DataModel" in archive.namelist(), "Missing embedded model"
        documents = {
            name: json.loads(archive.read(name))
            for name in archive.namelist()
            if name.startswith("Report/") and name.endswith(".json")
        }
        report = documents["Report/definition/report.json"]
        theme = report["themeCollection"]["customTheme"]
        assert theme["type"] == "RegisteredResources"
        assert "Report/StaticResources/RegisteredResources/" + theme["name"] in documents
        pages = {
            name: page for name, page in documents.items()
            if name.startswith("Report/definition/pages/") and name.endswith("/page.json")
        }
        assert {page["displayName"] for page in pages.values()} == expected
        count = 0
        for path, page in pages.items():
            prefix = path.rsplit("/", 1)[0] + "/visuals/"
            visuals = [doc for name, doc in documents.items() if name.startswith(prefix) and name.endswith("/visual.json")]
            assert visuals, f"Empty page: {page['displayName']}"
            identifiers = {visual["name"] for visual in visuals}
            assert len(identifiers) == len(visuals), "Duplicate visual identifiers"
            assert len({v["position"]["tabOrder"] for v in visuals}) == len(visuals), "Duplicate navigation order"
            for visual in visuals:
                p = visual["position"]
                assert p["x"] >= 0 and p["y"] >= 0
                assert p["x"] + p["width"] <= page["width"]
                assert p["y"] + p["height"] <= page["height"]
                check_fields(visual["visual"].get("query", {}))
            for interaction in page.get("visualInteractions", []):
                assert interaction["source"] in identifiers and interaction["target"] in identifiers
            count += len(visuals)
        print(f"PASS: Power BI archive, {len(pages)} pages, {count} visuals, theme resources and CSV field references")


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
    validate_report()
    print("Not checked: dependency installation, live SQL, notebook execution, Power BI rendering.")


if __name__ == "__main__":
    main()
