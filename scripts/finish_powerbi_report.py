"""Apply ProductPulse presentation settings while preserving the embedded model.

The input is a PBIX containing PBIR report definitions. This is an offline
package edit: reopen the result in Power BI Desktop to verify rendering.
Run with --output to stage a candidate without changing the input file.
"""

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VISUAL_SCHEMA = "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.14.0/schema.json"


def identity(label):
    return hashlib.sha256(label.encode()).hexdigest()[:20]


def expression(value):
    return {"expr": {"Literal": {"Value": value}}}


def string(value):
    return expression("'" + value.replace("'", "''") + "'")


def color(value):
    return {"solid": {"color": string(value)}}


def column(table, name, *, source=False):
    return {"Column": {"Expression": {"SourceRef": {"Source" if source else "Entity": table}}, "Property": name}}


def comparison(left, kind, value):
    return {"Comparison": {"ComparisonKind": kind, "Left": left, "Right": {"Literal": {"Value": value}}}}


def date(value):
    return "datetime'" + value + "T00:00:00'"


def conjunction(left, right):
    return {"And": {"Left": left, "Right": right}}


def query_filter(table, condition):
    return {"Version": 2, "From": [{"Name": "p", "Entity": table, "Type": 0}], "Where": [{"Condition": condition}]}


def add_snapshot_filter(page, table, field, condition):
    filters = page.setdefault("filterConfig", {}).setdefault("filters", [])
    name = identity("ProductPulse snapshot " + table)
    filters[:] = [item for item in filters if item["name"] != name]
    item = {"name": name, "displayName": "Observed through 31 Aug 2026", "type": "Advanced",
            "filter": query_filter(table, condition)}
    if field:
        item["field"] = column(table, field)
    filters.append(item)


def note(label, text, x, y, width, height):
    return {
        "$schema": VISUAL_SCHEMA, "name": identity(label),
        "position": {"x": x, "y": y, "width": width, "height": height, "z": 50, "tabOrder": 50},
        "visual": {"visualType": "textbox", "objects": {"general": [{"properties": {
            "paragraphs": [{"textRuns": [{"value": text, "textStyle": {
                "fontFamily": "Segoe UI", "fontSize": "11pt", "color": "#334155"}}],
                "horizontalTextAlignment": "left"}]}}]},
            "visualContainerObjects": {
                "background": [{"properties": {"show": expression("false")}}],
                "border": [{"properties": {"show": expression("false")}}],
                "subTitle": [{"properties": {"show": expression("false")}}],
                "title": [{"properties": {"show": expression("false")}}]}}}


def polish(source, output):
    with zipfile.ZipFile(source) as archive:
        if archive.testzip():
            raise ValueError("The source PBIX has a corrupt archive entry")
        entries = {item.filename: item for item in archive.infolist()}
        files = {name: archive.read(name) for name in entries}
    original_model = files["DataModel"]

    def read(name):
        return json.loads(files[name])

    def write(name, value):
        files[name] = (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")

    pages = {}
    for name in list(files):
        if name.startswith("Report/definition/pages/") and name.endswith("/page.json"):
            page = read(name)
            pages[page["displayName"]] = (name, page)
    expected = {"Executive Overview", "User Behaviour", "Retention", "Conversion Funnel"}
    if set(pages) != expected:
        raise ValueError("Expected the supplied four-page ProductPulse report")

    theme_bytes = (ROOT / "powerbi/theme.json").read_bytes()
    json.loads(theme_bytes)
    theme_name = "ProductPulse-Executive-" + hashlib.sha256(theme_bytes).hexdigest()[:8] + ".json"
    files["Report/StaticResources/RegisteredResources/" + theme_name] = theme_bytes
    report_path = "Report/definition/report.json"
    report = read(report_path)
    report["themeCollection"]["customTheme"] = {
        "name": theme_name, "type": "RegisteredResources",
        "reportVersionAtImport": copy.deepcopy(report["themeCollection"]["baseTheme"]["reportVersionAtImport"])}
    packages = report.setdefault("resourcePackages", [])
    package = next((p for p in packages if p["name"] == "RegisteredResources"), None)
    if package is None:
        package = {"name": "RegisteredResources", "type": "RegisteredResources", "items": []}
        packages.append(package)
    package["items"] = [item for item in package["items"] if item.get("name") != theme_name]
    package["items"].append({"name": theme_name, "path": theme_name, "type": "CustomTheme"})
    write(report_path, report)

    def add_visual(page_path, value):
        write(page_path.rsplit("/", 1)[0] + "/visuals/" + value["name"] + "/visual.json", value)

    for title, (page_path, page) in pages.items():
        prefix = page_path.rsplit("/", 1)[0] + "/visuals/"
        visuals = [(name, read(name)) for name in files if name.startswith(prefix) and name.endswith("/visual.json")]

        if title == "Executive Overview":
            add_snapshot_filter(page, "monthly_kpis", "month", comparison(column("p", "month", source=True), 3, date("2026-09-01")))
        elif title == "User Behaviour":
            add_snapshot_filter(page, "daily_activity", "date", comparison(column("p", "date", source=True), 3, date("2026-09-01")))
        elif title == "Retention":
            # The existing CSV has just one post-snapshot cell: Aug 2026,
            # period 1. Bound every recent cohort, without adding model columns.
            cohort = column("p", "cohort_month", source=True)
            period = column("p", "period_number", source=True)
            condition = comparison(cohort, 4, date("2025-08-01"))
            for month_index in range(12):
                year = 2025 + (8 + month_index) // 12
                month = (8 + month_index) % 12 + 1
                clause = conjunction(comparison(cohort, 0, date(f"{year}-{month:02d}-01")),
                                     comparison(period, 4, f"{11-month_index}L"))
                condition = {"Or": {"Left": condition, "Right": clause}}
            add_snapshot_filter(page, "cohort_retention", None, condition)

        for name, document in visuals:
            visual = document["visual"]
            kind = visual["visualType"]
            visual.setdefault("visualContainerObjects", {})["subTitle"] = [{"properties": {"show": expression("false")}}]
            if title == "Executive Overview" and kind == "tableEx":
                replacement = note("Executive data note", "As of 31 Aug 2026. Cards show August billing KPIs. Customer attributes are real; usage and billing histories are reconstructed or simulated.", 20, 820, 1240, 65)
                replacement["name"] = document["name"]
                document = replacement
            elif title == "User Behaviour" and kind != "textbox" and kind != "slicer":
                document["position"].update(y=140 if kind == "lineChart" else 470, height=310 if kind == "lineChart" else 335)
                if kind == "clusteredBarChart":
                    props = visual["visualContainerObjects"]["title"][0]["properties"]
                    original = props["text"]["expr"]["Literal"]["Value"].strip("'")
                    if "all-time" not in original.lower():
                        props["text"] = string(original + " — all-time")
            elif title == "Retention" and kind == "pivotTable":
                field = visual["query"]["queryState"]["Values"]["projections"][0]["queryRef"]
                stops = {
                    "min": {"color": {"Literal": {"Value": "'#FFFFFF'"}}, "value": {"Literal": {"Value": "0D"}}},
                    "max": {"color": {"Literal": {"Value": "'#8FAADC'"}}, "value": {"Literal": {"Value": "100D"}}},
                    "nullColoringStrategy": {"strategy": {"Literal": {"Value": "'noColor'"}}}}
                gradient = {"Input": {"SelectRef": {"ExpressionName": field}},
                            "FillRule": {"linearGradient2": stops}}
                visual["objects"] = {
                    "values": [{"properties": {"fontSize": expression("9D"), "fontColorPrimary": color("#1A1A1A"), "fontColorSecondary": color("#1A1A1A")}},
                               {"properties": {"backColor": {"solid": {"color": {"expr": {"FillRule": gradient}}}}},
                                "selector": {"data": [{"dataViewWildcard": {"matchingOption": 1}}], "metadata": field}}],
                    "general": [{"properties": {"formatString": string("MMM yyyy")}, "selector": {"metadata": "cohort_month"}}],
                    "columnHeaders": [{"properties": {"fontSize": expression("9D"), "autoSizeColumnWidth": expression("true"), "columnAdjustment": string("growToFit")}}],
                    "rowHeaders": [{"properties": {"fontSize": expression("9D"), "wordWrap": expression("false")}}],
                    "subTotals": [{"properties": {"rowSubtotals": expression("false"), "columnSubtotals": expression("false")}}]}
                visual["visualContainerObjects"]["stylePreset"] = [{"properties": {"name": string("None")}}]
                visual["visualContainerObjects"]["title"][0]["properties"]["text"] = string("Cohort activity retention (%) — observed through Aug 2026")
                visual["query"]["sortDefinition"] = {"sort": [{"field": column("cohort_retention", "cohort_month"), "direction": "Ascending"}], "isDefaultSort": False}
            elif title == "Retention" and kind in ("lineChart", "clusteredBarChart"):
                document["position"]["height"] = 340
            elif title == "Conversion Funnel" and kind == "tableEx":
                visual.setdefault("objects", {})["total"] = [{"properties": {"totals": expression("false")}}]
            elif title == "Conversion Funnel" and kind == "funnel":
                visual.setdefault("objects", {})["labels"] = [{"properties": {"show": expression("true"), "labelDisplayUnits": expression("0D"), "labelPrecision": expression("0L")}}]
            write(name, document)

        if title == "User Behaviour":
            slicer_id = identity("ProductPulse daily date slicer")
            range_condition = conjunction(comparison(column("p", "date", source=True), 2, date("2025-09-01")),
                                          comparison(column("p", "date", source=True), 3, date("2026-09-01")))
            add_visual(page_path, {"$schema": VISUAL_SCHEMA, "name": slicer_id,
                "position": {"x": 20, "y": 20, "width": 610, "height": 100, "z": 40, "tabOrder": 0},
                "visual": {"visualType": "slicer", "query": {"queryState": {"Values": {"projections": [{
                    "field": column("daily_activity", "date"), "queryRef": "daily_activity.date", "nativeQueryRef": "date"}]}}},
                    "objects": {"data": [{"properties": {"mode": string("Between"), "startDate": expression(date("2025-09-01")), "endDate": expression(date("2026-08-31"))}}],
                                "general": [{"properties": {"filter": {"filter": query_filter("daily_activity", range_condition)}}}],
                                "header": [{"properties": {"show": expression("true"), "text": string("Daily activity date range")}}]}}})
            add_visual(page_path, note("User behaviour filter scope", "The date range filters the two daily charts. Feature adoption and country summaries cover all exported history.", 650, 20, 610, 100))
            add_visual(page_path, note("User behaviour data note", "Synthetic usage history. Late-August spikes and the drop at the snapshot boundary are generation artefacts under investigation, not verified product behaviour.", 20, 820, 1240, 65))
            interactions = page.setdefault("visualInteractions", [])
            interactions[:] = [item for item in interactions if item["source"] != slicer_id]
            for _, original in visuals:
                kind = original["visual"]["visualType"]
                if kind in ("lineChart", "clusteredBarChart"):
                    interactions.append({"source": slicer_id, "target": original["name"],
                                         "type": "DataFilter" if kind == "lineChart" else "NoFilter"})
        elif title == "Retention":
            add_visual(page_path, note("Retention data note", "Activity retention; the curve is unweighted across available cohorts. Channel differences reflect simulation assumptions and do not support causal or marketing-budget conclusions.", 20, 820, 1240, 65))
        elif title == "Conversion Funnel":
            add_visual(page_path, note("Conversion funnel data note", "Starts at signup; no visitor data is available. Stages overlap, so their counts must not be summed. The final stage reaches 56.51% of signups. Histories are reconstructed or simulated.", 20, 765, 1240, 115))
        page_visuals = [(name, read(name)) for name in files if name.startswith(prefix) and name.endswith("/visual.json")]
        page_visuals.sort(key=lambda item: (item[1]["position"]["y"], item[1]["position"]["x"]))
        for order, (name, document) in enumerate(page_visuals):
            document["position"]["tabOrder"] = order
            write(name, document)
        write(page_path, page)

    # Validate layout and JSON before writing any output.
    for name, data in files.items():
        if name.startswith("Report/") and name.endswith(".json"):
            json.loads(data)
        if name.endswith("/visual.json"):
            doc = read(name)
            position = doc["position"]
            if not (0 <= position["x"] and 0 <= position["y"] and position["x"] + position["width"] <= 1280 and position["y"] + position["height"] <= 900):
                raise ValueError("Visual outside canvas: " + name)
    assert files["DataModel"] == original_model
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.resolve() == source.resolve():
        backup = source.with_name(source.stem + ".before-polish.pbix.bak")
        if not backup.exists():
            shutil.copy2(source, backup)
    handle, temporary = tempfile.mkstemp(prefix=output.stem + "-", suffix=".tmp", dir=output.parent)
    os.close(handle)
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for name, data in files.items():
                archive.writestr(entries[name] if name in entries else name, data)
        with zipfile.ZipFile(temporary) as archive:
            assert archive.testzip() is None
            assert archive.read("DataModel") == original_model
        os.replace(temporary, output)
    finally:
        if os.path.exists(temporary):
            os.remove(temporary)
    print(f"Updated {output}; embedded DataModel preserved. Desktop rendering verification is pending.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", type=Path, default=ROOT / "powerbi/ProductPulse_Updated.pbix")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    polish(args.source, args.output or args.source)
