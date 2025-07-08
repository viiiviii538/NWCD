#!/usr/bin/env python3

"""Generate an HTML report from device scan results."""
from __future__ import annotations

import argparse
import json
import html
from pathlib import Path
from typing import Any, Dict, List

from security_score import calc_security_score
from report_utils import calc_utm_items

try:
    import pdfkit  # type: ignore
except Exception:  # pragma: no cover - optional
    pdfkit = None
try:
    from weasyprint import HTML as WeasyHTML  # type: ignore
except Exception:  # pragma: no cover - optional
    WeasyHTML = None

CSS = """
body { font-family: Arial, sans-serif; }
table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
th, td { border: 1px solid #ccc; padding: 4px; text-align: left; }
th { background: #eee; }
.score-high { background: #f8d7da; }
.score-mid { background: #fff3cd; }
"""

def _escape(val: Any) -> str:
    return html.escape(str(val))

def _collect_countries(dev: Dict[str, Any]) -> List[str]:
    countries = [c for c in dev.get("countries", []) if c]
    comms = dev.get("communications") or dev.get("destinations") or []
    for c in comms:
        country = c.get("country")
        if country:
            countries.append(country)
    return [str(c).upper() for c in countries]

def generate_html(data: Any) -> str:
    """Generate HTML from device list or combined result dict."""
    if isinstance(data, dict) and "devices" in data:
        devices = data.get("devices", [])
        lan_sec = data.get("lan_security")
    else:
        devices = data
        lan_sec = None

    parts: List[str] = ["<html><head><meta charset='utf-8'><style>", CSS, "</style></head><body>"]
    parts.append("<h1>Network Report</h1>")
    parts.append("<h2>Devices</h2><table><tr><th>IP</th><th>MAC</th><th>Vendor</th></tr>")
    for dev in devices:
        ip = dev.get("ip") or dev.get("device") or ""
        parts.append(f"<tr><td>{_escape(ip)}</td><td>{_escape(dev.get('mac',''))}</td><td>{_escape(dev.get('vendor',''))}</td></tr>")
    parts.append("</table>")

    parts.append("<h2>Open Ports</h2>")
    for dev in devices:
        ip = dev.get("ip") or dev.get("device") or ""
        ports = [str(p) for p in dev.get("open_ports", [])]
        parts.append(f"<h3>{_escape(ip)}</h3>")
        if ports:
            parts.append("<ul>")
            for p in ports:
                parts.append(f"<li>{_escape(p)}</li>")
            parts.append("</ul>")
        else:
            parts.append("<p>None</p>")

    parts.append("<h2>Communications</h2>")
    for dev in devices:
        ip = dev.get("ip") or dev.get("device") or ""
        dests = dev.get("communications") or dev.get("destinations") or []
        parts.append(f"<h3>{_escape(ip)}</h3>")
        if dests:
            parts.append("<table><tr><th>IP</th><th>Domain</th><th>Country</th></tr>")
            for d in dests:
                parts.append(f"<tr><td>{_escape(d.get('ip',''))}</td><td>{_escape(d.get('domain',''))}</td><td>{_escape(d.get('country',''))}</td></tr>")
            parts.append("</table>")
        else:
            parts.append("<p>None</p>")

    parts.append("<h2>Security Scores</h2><table><tr><th>IP</th><th>Score</th></tr>")
    all_utm = set()
    for dev in devices:
        ip = dev.get("ip") or dev.get("device") or ""
        ports = [str(p) for p in dev.get("open_ports", [])]
        countries = _collect_countries(dev)
        score, _ = calc_security_score(ports, countries)
        utm = calc_utm_items(score, ports, countries)
        all_utm.update(utm)
        cls = ""
        if score >= 8:
            cls = "score-high"
        elif score >= 5:
            cls = "score-mid"
        parts.append(f"<tr class='{cls}'><td>{_escape(ip)}</td><td>{score}</td></tr>")
    parts.append("</table>")

    parts.append("<h2>UTMで防御可能な項目</h2>")
    if all_utm:
        parts.append("<ul>")
        for item in sorted(all_utm):
            parts.append(f"<li>{_escape(item)}</li>")
        parts.append("</ul>")
    else:
        parts.append("<p>なし</p>")

    if lan_sec:
        parts.append("<h2>LANセキュリティ診断</h2>")
        parts.append("<table><tr><th>項目</th><th>状態</th><th>詳細</th></tr>")
        for key, res in lan_sec.items():
            status = res.get("status", "")
            detail = res.get("details", "")
            utm = ",".join(res.get("utm", []))
            if status == "warning" and utm:
                detail += f" (このリスクはUTMで防げます: {utm})"
            parts.append(
                f"<tr><td>{_escape(key)}</td><td>{_escape(status)}</td><td>{_escape(detail)}</td></tr>"
            )
        parts.append("</table>")

    parts.append("</body></html>")
    return "".join(parts)


def generate_html_report(devices: List[Dict[str, Any]]) -> str:
    """Wrapper that maintains backwards compatibility."""
    return generate_html(devices)

def convert_to_pdf(html_path: Path, pdf_path: Path) -> None:
    if pdfkit:
        pdfkit.from_file(str(html_path), str(pdf_path))
    elif WeasyHTML:
        WeasyHTML(filename=str(html_path)).write_pdf(str(pdf_path))
    else:
        raise RuntimeError("pdfkit or weasyprint is required for PDF output")

def main() -> None:
    parser = argparse.ArgumentParser(description="Create HTML report from scan results")
    parser.add_argument("input", help="Input JSON file with scan data")
    parser.add_argument("-o", "--output", default="scan_report.html", help="Output HTML file")
    parser.add_argument("--pdf", action="store_true", help="Also generate PDF if possible")
    args = parser.parse_args()

    with open(args.input, "r", encoding="utf-8") as f:
        data = json.load(f)


    html_data = generate_html(data)
    out_path = Path(args.output)
    out_path.write_text(html_data, encoding="utf-8")
    print(f"HTML report written to {out_path}")

    if args.pdf:
        pdf_path = out_path.with_suffix(".pdf")
        try:
            convert_to_pdf(out_path, pdf_path)
            print(f"PDF written to {pdf_path}")
        except Exception as e:
            print(f"PDF conversion failed: {e}")

if __name__ == "__main__":
    main()
