import array
import json
from abc import ABC, abstractmethod

import oracledb
import psycopg

from .settings import settings


class VectorStore(ABC):
    @abstractmethod
    def replace_source(self, source_file: str, rows: list[dict]) -> int:
        raise NotImplementedError

    @abstractmethod
    def search(self, embedding: list[float], top_k: int) -> list[dict]:
        raise NotImplementedError

    @abstractmethod
    def health(self) -> dict:
        raise NotImplementedError


class OracleVectorStore(VectorStore):
    def _connect(self):
        config_dir = settings.oracle_wallet_location or None
        wallet_location = settings.oracle_wallet_location or None
        wallet_password = settings.oracle_wallet_password or None
        return oracledb.connect(
            user=settings.oracle_user,
            password=settings.oracle_password,
            dsn=settings.oracle_dsn,
            config_dir=config_dir,
            wallet_location=wallet_location,
            wallet_password=wallet_password,
        )

    def replace_source(self, source_file: str, rows: list[dict]) -> int:
        with self._connect() as conn:
            with conn.cursor() as cursor:
                cursor.execute("DELETE FROM demo_pdf_chunks WHERE source_file = :source_file", source_file=source_file)
                cursor.executemany(
                    """
                    INSERT INTO demo_pdf_chunks
                      (source_file, page_number, chunk_index, chunk_text, embedding)
                    VALUES
                      (:source_file, :page_number, :chunk_index, :chunk_text, :embedding)
                    """,
                    [
                        {
                            **row,
                            "embedding": array.array("f", row["embedding"]),
                        }
                        for row in rows
                    ],
                )
            conn.commit()
        return len(rows)

    def search(self, embedding: list[float], top_k: int) -> list[dict]:
        with self._connect() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT id, source_file, page_number, chunk_index, chunk_text,
                           VECTOR_DISTANCE(embedding, :query_vector, COSINE) AS distance
                    FROM demo_pdf_chunks
                    ORDER BY distance
                    FETCH FIRST :top_k ROWS ONLY
                    """,
                    query_vector=array.array("f", embedding),
                    top_k=top_k,
                )
                return [
                    {
                        "id": row[0],
                        "source_file": row[1],
                        "page_number": row[2],
                        "chunk_index": row[3],
                        "chunk_text": row[4].read() if hasattr(row[4], "read") else row[4],
                        "distance": float(row[5]),
                    }
                    for row in cursor
                ]

    def health(self) -> dict:
        return {"adapter": "oracle", "dsn_configured": bool(settings.oracle_dsn)}


class PgVectorStore(VectorStore):
    def _connect(self):
        return psycopg.connect(settings.database_url)

    @staticmethod
    def _vector_literal(embedding: list[float]) -> str:
        return json.dumps(embedding)

    def replace_source(self, source_file: str, rows: list[dict]) -> int:
        with self._connect() as conn:
            with conn.cursor() as cursor:
                cursor.execute("DELETE FROM demo_pdf_chunks WHERE source_file = %s", (source_file,))
                cursor.executemany(
                    """
                    INSERT INTO demo_pdf_chunks
                      (source_file, page_number, chunk_index, chunk_text, embedding)
                    VALUES
                      (%s, %s, %s, %s, %s::vector)
                    """,
                    [
                        (
                            row["source_file"],
                            row["page_number"],
                            row["chunk_index"],
                            row["chunk_text"],
                            self._vector_literal(row["embedding"]),
                        )
                        for row in rows
                    ],
                )
        return len(rows)

    def search(self, embedding: list[float], top_k: int) -> list[dict]:
        with self._connect() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT id, source_file, page_number, chunk_index, chunk_text,
                           embedding <=> %s::vector AS distance
                    FROM demo_pdf_chunks
                    ORDER BY embedding <=> %s::vector
                    LIMIT %s
                    """,
                    (self._vector_literal(embedding), self._vector_literal(embedding), top_k),
                )
                return [
                    {
                        "id": row[0],
                        "source_file": row[1],
                        "page_number": row[2],
                        "chunk_index": row[3],
                        "chunk_text": row[4],
                        "distance": float(row[5]),
                    }
                    for row in cursor
                ]

    def health(self) -> dict:
        return {"adapter": "pgvector", "database_url_configured": bool(settings.database_url)}


def get_store() -> VectorStore:
    if settings.vector_db == "oracle":
        return OracleVectorStore()
    if settings.vector_db == "pgvector":
        return PgVectorStore()
    raise ValueError("VECTOR_DB must be either 'oracle' or 'pgvector'")
