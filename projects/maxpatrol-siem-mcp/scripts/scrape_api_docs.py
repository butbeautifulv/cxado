#!/usr/bin/env python3
"""Scrape MaxPatrol 10 API docs from PT help portal into Markdown."""

from __future__ import annotations

import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import html2text

BASE = "https://help.ptsecurity.com/api/v2/documents"
LOCALE = "ru-RU"
PROJECT = "mp10"
VERSION = "27.2"
DOC_TYPE = "help"
API_SECTION_TITLE = "Виды запросов к API"
HEADERS = {
    "Accept": "application/json",
    "User-Agent": "Mozilla/5.0 (compatible; maxpatrol-siem-mcp-doc-scraper/1.0)",
    "Referer": "https://help.ptsecurity.com/",
}
SOURCE_URL = (
    f"https://help.ptsecurity.com/{LOCALE}/projects/{PROJECT}/{VERSION}/help/2697416843"
)

PLACEHOLDERS = [
    "Корневой URL API",
    "Идентификатор приложения",
    "Привилегия",
    "Идентификатор инцидента",
    "Идентификатор события",
    "Идентификатор задачи",
    "Идентификатор актива",
    "Идентификатор группы",
    "Идентификатор инфраструктуры",
    "Идентификатор табличного списка",
    "Идентификатор подписчика",
    "Идентификатор профиля",
    "Идентификатор скана",
    "Идентификатор учетной записи",
    "Токен",
]

_CONVERTER = html2text.HTML2Text()
_CONVERTER.body_width = 0
_CONVERTER.ignore_images = True
_CONVERTER.ignore_emphasis = False
_CONVERTER.single_line_break = False
_CONVERTER.wrap_links = False


def fetch_json(url: str, retries: int = 3) -> dict | list:
    last_err: Exception | None = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=60) as resp:
                return json.load(resp)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            last_err = exc
            time.sleep(0.5 * (attempt + 1))
    raise RuntimeError(f"Failed to fetch {url}: {last_err}") from last_err


def normalize_pt_html(content: str) -> str:
    for name in PLACEHOLDERS:
        content = content.replace(f"&lt;{name}&gt;", f"<code>{name}</code>")
        content = content.replace(f"<{name}>", f"<code>{name}</code>")
    content = re.sub(r"<code-block>\s*", "<pre><code>", content)
    content = content.replace("</code-block>", "</code></pre>")
    content = content.replace("<code-line>", "").replace("</code-line>", "\n")
    content = content.replace("<monospace>", "<code>").replace("</monospace>", "</code>")
    return content


def postprocess_markdown(text: str) -> str:
    text = re.sub(r"\n{3,}", "\n\n", text)
    lines: list[str] = []
    i = 0
    split = text.splitlines(keepends=True)
    while i < len(split):
        line = split[i]
        if re.match(r"^[ \t]{4,}(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS)\b", line):
            block: list[str] = []
            while i < len(split) and (split[i].strip() == "" or split[i][:1] in " \t"):
                if split[i].strip():
                    block.append(re.sub(r"^[ \t]+", "", split[i].rstrip()))
                i += 1
            lines.append("```http\n" + "\n".join(block) + "\n```\n")
            continue
        lines.append(line)
        i += 1
    return "".join(lines).strip()


def html_to_markdown(content: str) -> str:
    return postprocess_markdown(_CONVERTER.handle(normalize_pt_html(content)))


def find_node(nodes: list[dict], title: str) -> dict | None:
    for node in nodes:
        if node.get("title") == title:
            return node
        children = node.get("children") or []
        found = find_node(children, title)
        if found:
            return found
    return None


def collect_pages(node: dict, path: list[str] | None = None) -> list[tuple[str, str, int]]:
    path = path or []
    title = node.get("title") or ""
    full_path = path + [title]
    pages: list[tuple[str, str, int]] = [(node["id"], " > ".join(full_path), len(full_path))]
    for child in node.get("children") or []:
        pages.extend(collect_pages(child, full_path))
    return pages


def heading_for_depth(depth: int, title: str) -> str:
    level = min(depth + 1, 6)
    return f"{'#' * level} {title}"


def build_markdown() -> str:
    menu = fetch_json(f"{BASE}/menu/{LOCALE}/{PROJECT}/{VERSION}/{DOC_TYPE}")
    api_root = find_node(menu, API_SECTION_TITLE)
    if not api_root:
        raise SystemExit(f"Section not found: {API_SECTION_TITLE}")

    pages = collect_pages(api_root)
    lines = [
        "# MaxPatrol 10 27.2 — REST API",
        "",
        f"> Источник: [{SOURCE_URL}]({SOURCE_URL})  ",
        f"> Справочный портал Positive Technologies, раздел «{API_SECTION_TITLE}».  ",
        f"> Автоматически собрано из help API (`{len(pages)}` страниц).",
        "",
        "## Содержание",
        "",
    ]

    for _doc_id, path, depth in pages:
        anchor = re.sub(r"[^\w\-]+", "-", path.lower()).strip("-")
        indent = "  " * max(0, depth - 1)
        title = path.split(" > ")[-1]
        lines.append(f"{indent}- [{title}](#{anchor})")

    lines.append("")
    lines.append("---")
    lines.append("")

    for idx, (doc_id, path, depth) in enumerate(pages):
        doc = fetch_json(
            f"{BASE}/document/{LOCALE}/{PROJECT}/{VERSION}/{DOC_TYPE}/{doc_id}"
        )
        title = doc.get("title") or path.split(" > ")[-1]
        content_html = doc.get("content") or ""
        body = html_to_markdown(content_html)
        page_url = (
            f"https://help.ptsecurity.com/{LOCALE}/projects/"
            f"{PROJECT}/{VERSION}/help/{doc.get('id', doc_id)}"
        )
        lines.append(heading_for_depth(depth, title))
        lines.append("")
        lines.append(f"**Страница справки:** <{page_url}>  ")
        lines.append(f"**Путь:** `{path}`")
        lines.append("")
        if body:
            lines.append(body)
        else:
            lines.append("_Нет текстового содержимого._")
        lines.append("")
        lines.append("---")
        lines.append("")
        if idx % 10 == 9:
            time.sleep(0.2)

    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    out = Path(__file__).resolve().parents[1] / "docs" / "API.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    print(f"Scraping {API_SECTION_TITLE}...", file=sys.stderr)
    md = build_markdown()
    out.write_text(md, encoding="utf-8")
    print(f"Wrote {out} ({len(md):,} bytes)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
