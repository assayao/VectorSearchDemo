CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS demo_pdf_chunks (
  id bigserial PRIMARY KEY,
  source_file text NOT NULL,
  page_number integer NOT NULL,
  chunk_index integer NOT NULL,
  chunk_text text NOT NULL,
  embedding vector(768) NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS demo_pdf_chunks_src_idx
  ON demo_pdf_chunks (source_file, page_number, chunk_index);

CREATE INDEX IF NOT EXISTS demo_pdf_chunks_vec_idx
  ON demo_pdf_chunks
  USING hnsw (embedding vector_cosine_ops);
