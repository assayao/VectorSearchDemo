from pathlib import Path

from fastapi import FastAPI
from pydantic import BaseModel, Field

from .ollama_client import chat_answer, embed_texts
from .pdf_ingest import chunk_text, extract_pdf_pages
from .settings import settings
from .stores import get_store


app = FastAPI(title="Vector Search Orchestration Demo")


class SearchRequest(BaseModel):
    query: str = Field(min_length=1)
    top_k: int = Field(default=5, ge=1, le=20)


@app.get("/health")
def health():
    return {
        "ok": True,
        "pdf_path": settings.pdf_path,
        "embedding_model": settings.embed_model,
        "chat_model": settings.chat_model,
        "store": get_store().health(),
    }


@app.post("/ingest")
async def ingest():
    pdf_path = Path(settings.pdf_path)
    pages = extract_pdf_pages(str(pdf_path))
    pending_rows: list[dict] = []

    for page_number, page_text in pages:
        for chunk_index, chunk in enumerate(
            chunk_text(page_text, settings.chunk_size, settings.chunk_overlap),
            start=1,
        ):
            pending_rows.append(
                {
                    "source_file": pdf_path.name,
                    "page_number": page_number,
                    "chunk_index": chunk_index,
                    "chunk_text": chunk,
                }
            )

    embeddings = await embed_texts([row["chunk_text"] for row in pending_rows])
    rows = [{**row, "embedding": embedding} for row, embedding in zip(pending_rows, embeddings)]
    inserted = get_store().replace_source(pdf_path.name, rows)
    return {"source_file": pdf_path.name, "pages": len(pages), "chunks": inserted}


@app.post("/search")
async def search(request: SearchRequest):
    query_embedding = (await embed_texts([request.query]))[0]
    results = get_store().search(query_embedding, request.top_k)
    return {"query": request.query, "results": results}


@app.post("/ask")
async def ask(request: SearchRequest):
    query_embedding = (await embed_texts([request.query]))[0]
    results = get_store().search(query_embedding, request.top_k)
    answer = await chat_answer(request.query, results)
    sources = [
        {
            "source_file": item["source_file"],
            "page_number": item["page_number"],
            "chunk_index": item["chunk_index"],
            "distance": item["distance"],
        }
        for item in results
    ]
    return {"query": request.query, "answer": answer, "sources": sources}
