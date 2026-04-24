import os
from dataclasses import dataclass

from dotenv import load_dotenv


load_dotenv()


@dataclass(frozen=True)
class Settings:
    vector_db: str = os.getenv("VECTOR_DB", "oracle").lower()
    pdf_path: str = os.getenv("PDF_PATH", "move-oracle-cloud-using-zero-downtime-migration.pdf")
    ollama_base_url: str = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434").rstrip("/")
    embed_model: str = os.getenv("EMBED_MODEL", "nomic-embed-text")
    chat_model: str = os.getenv("CHAT_MODEL", "llama3.2")
    oracle_user: str = os.getenv("ORACLE_USER", "admin")
    oracle_password: str = os.getenv("ORACLE_PASSWORD", "")
    oracle_dsn: str = os.getenv("ORACLE_DSN", "")
    oracle_wallet_location: str = os.getenv("ORACLE_WALLET_LOCATION", "")
    oracle_wallet_password: str = os.getenv("ORACLE_WALLET_PASSWORD", "")
    database_url: str = os.getenv("DATABASE_URL", "")
    chunk_size: int = int(os.getenv("CHUNK_SIZE", "1200"))
    chunk_overlap: int = int(os.getenv("CHUNK_OVERLAP", "200"))


settings = Settings()
