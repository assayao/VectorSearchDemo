import httpx

from .settings import settings


async def embed_texts(texts: list[str]) -> list[list[float]]:
    async with httpx.AsyncClient(timeout=120) as client:
        response = await client.post(
            f"{settings.ollama_base_url}/api/embed",
            json={"model": settings.embed_model, "input": texts},
        )
        response.raise_for_status()
        payload = response.json()
    return payload["embeddings"]


async def chat_answer(query: str, contexts: list[dict]) -> str:
    context_text = "\n\n".join(
        f"Source {idx}: page {item['page_number']}, chunk {item['chunk_index']}\n{item['chunk_text']}"
        for idx, item in enumerate(contexts, start=1)
    )
    prompt = (
        "Answer the question using only the provided PDF excerpts. "
        "If the answer is not present, say so. Cite source numbers.\n\n"
        f"Question: {query}\n\n"
        f"PDF excerpts:\n{context_text}"
    )

    async with httpx.AsyncClient(timeout=120) as client:
        response = await client.post(
            f"{settings.ollama_base_url}/api/chat",
            json={
                "model": settings.chat_model,
                "messages": [{"role": "user", "content": prompt}],
                "stream": False,
            },
        )
        response.raise_for_status()
        payload = response.json()
    return payload["message"]["content"]
