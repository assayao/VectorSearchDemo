from pathlib import Path

import fitz


def extract_pdf_pages(pdf_path: str) -> list[tuple[int, str]]:
    path = Path(pdf_path)
    if not path.exists():
        raise FileNotFoundError(f"PDF not found: {path}")

    pages: list[tuple[int, str]] = []
    with fitz.open(path) as doc:
        for page_index, page in enumerate(doc, start=1):
            text = " ".join(page.get_text("text").split())
            if text:
                pages.append((page_index, text))
    return pages


def chunk_text(text: str, chunk_size: int, overlap: int) -> list[str]:
    if chunk_size <= overlap:
        raise ValueError("CHUNK_SIZE must be larger than CHUNK_OVERLAP")

    chunks: list[str] = []
    start = 0
    while start < len(text):
        end = min(start + chunk_size, len(text))
        chunks.append(text[start:end].strip())
        if end == len(text):
            break
        start = end - overlap
    return [chunk for chunk in chunks if chunk]
