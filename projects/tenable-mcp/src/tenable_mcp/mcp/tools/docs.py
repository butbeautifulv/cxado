from __future__ import annotations

from pathlib import Path


def _api_doc_path() -> Path:
    return Path(__file__).resolve().parents[4] / "docs" / "API.md"


async def search_api_docs(query: str, max_results: int = 5) -> str:
    if not query.strip():
        return "Укажите непустой поисковый запрос."

    path = _api_doc_path()
    if not path.is_file():
        return f"Файл справки не найден: {path}"

    text = path.read_text(encoding="utf-8")
    needle = query.casefold()
    lines = text.splitlines()
    hits: list[str] = []
    for idx, line in enumerate(lines):
        if needle in line.casefold():
            start = max(0, idx - 2)
            end = min(len(lines), idx + 8)
            snippet = "\n".join(lines[start:end])
            hits.append(f"--- match at line {idx + 1} ---\n{snippet}")
            if len(hits) >= max_results:
                break

    if not hits:
        return f"Совпадений по запросу '{query}' не найдено."

    return "\n\n".join(hits)
