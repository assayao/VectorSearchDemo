# Vector Search Orchestration Demo

This demo ingests the PDF in this folder and exposes a small API for semantic search and RAG-style answers.

## Recommended Free Stack

Use this path for the demo:

| Layer | Choice | Why |
| --- | --- | --- |
| LLM runtime | Ollama | Free local runtime with HTTP APIs for embeddings and chat. |
| Embeddings | `nomic-embed-text` | Good free text embedding model, small enough for a laptop, 768 dimensions. |
| Chat model | `llama3.2` | Free local model, reasonable for summaries and RAG answers. |
| Always-free autonomous DB | Oracle Autonomous AI Database Always Free | Managed/autonomous Oracle database with native `VECTOR` search support in 23ai/26ai-capable regions. |
| API | FastAPI | Simple REST API for ingest, search, and ask endpoints. |
| Orchestration | Terraform | Spins up the free Autonomous DB and optional API VM in OCI. |

Oracle's Always Free Autonomous AI Database currently provides up to two Always Free autonomous databases per tenancy, about 20 GB storage per database, and does not bill the instance until it is updated to paid. Always Free databases may stop after 7 days of inactivity and can be reclaimed after extended stopped/inactive periods, so keep that in mind for long-running demos.

## Existing DB Option

If you already have a database:

1. Existing Oracle AI Database 23ai/26ai or Autonomous AI Database:
   Use the same `oracle` adapter and `sql/oracle_schema.sql`.
2. Existing PostgreSQL with `pgvector`:
   Use the `pgvector` adapter and `sql/pgvector_schema.sql`.

For an Oracle-focused orchestration demo, Oracle Autonomous AI Database Always Free is the best fit because the autonomous DB and vector capability live in one platform. PostgreSQL/pgvector is a useful fallback when the environment already has Postgres.

## Terraform Orchestration

The Terraform stack is in `VectorDemoStack/`.

```powershell
cd VectorDemoStack
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

By default it creates an Oracle Autonomous AI Database Always Free instance and downloads a wallet zip. Set `enable_api_vm = true` if you also want Terraform to create an Always Free eligible Ampere A1 VM for the API/Ollama runtime.

For an existing DB, set `create_autonomous_database = false` and configure the API `.env` manually for either Oracle or PostgreSQL/pgvector.

For OCI Resource Manager, keep real secrets out of the uploaded bundle and prefer stack variables for:

- `autonomous_db_admin_password`
- `autonomous_db_wallet_password`
- tenancy- and compartment-specific OCIDs

The checked-in sample file is [terraform.tfvars.example](C:/Users/assay/OneDrive/LABS/LABS/AIVectordb/VectorDemoStack/terraform.tfvars.example). The real `terraform.tfvars` stays local and is ignored by Git.

### Fully Automated VM Path

For a zero-touch demo deployment from Git:

- set `enable_api_vm = true`
- set `api_repo_url` to the public Git repository URL for this project
- leave `require_mtls_connections = false` unless you explicitly want wallet-based mTLS on the VM
- set `create_reserved_public_ip = true` if you want the stack to create and attach a stable public IP automatically

In that mode the VM cloud-init flow:

1. installs Ollama, Python, Git, and unzip
2. clones the Git repo
3. installs Python dependencies
4. writes the app `.env`
5. creates the Oracle schema
6. registers a `systemd` service for FastAPI
7. starts the API
8. optionally ingests the PDF on first boot

If you already have a reserved public IP OCID, keep in mind that attaching an existing reserved IP cleanly in a fresh OCI RM stack is less portable than letting the stack create its own reserved IP resource.

## API

Start the API after installing dependencies:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
```

Pull the local models:

```powershell
ollama pull nomic-embed-text
ollama pull llama3.2
```

Create the database table using one of:

```powershell
sqlplus user/password@service @sql/oracle_schema.sql
psql "$env:DATABASE_URL" -f sql/pgvector_schema.sql
```

Run:

```powershell
uvicorn vector_demo.api:app --reload
```

Endpoints:

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/health` | Checks API and DB configuration. |
| `POST` | `/ingest` | Extracts, chunks, embeds, and stores the root PDF. |
| `POST` | `/search` | Returns the nearest chunks for a question. |
| `POST` | `/ask` | Retrieves relevant chunks and asks the local chat model for an answer with sources. |

Example:

```powershell
Invoke-RestMethod -Method Post http://127.0.0.1:8000/ingest
Invoke-RestMethod -Method Post http://127.0.0.1:8000/search -Body (@{query="How does zero downtime migration work?"; top_k=5} | ConvertTo-Json) -ContentType "application/json"
Invoke-RestMethod -Method Post http://127.0.0.1:8000/ask -Body (@{query="What are the main migration steps?"; top_k=5} | ConvertTo-Json) -ContentType "application/json"
```

## Configuration

Set `VECTOR_DB` to `oracle` for Oracle Autonomous AI Database or existing Oracle. Set it to `pgvector` for existing PostgreSQL.

For Oracle Autonomous AI Database, download the wallet from OCI and set `ORACLE_WALLET_LOCATION` plus the service name from `tnsnames.ora`, for example `mydb_high`.

## Sources Checked

- [Oracle Always Free Autonomous AI Database](https://docs.oracle.com/en-us/iaas/autonomous-database-shared/doc/autonomous-always-free.html)
- [Oracle AI Vector Search overview](https://docs.oracle.com/en/database/oracle/oracle-database/26/vecse/overview-ai-vector-search.html)
- [Oracle `VECTOR_DISTANCE`](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqlrf/vector_distance.html)
- [python-oracledb VECTOR data](https://python-oracledb.readthedocs.io/en/latest/user_guide/vector_data_type.html)
- [Ollama embeddings API](https://docs.ollama.com/api/embed)
- [Ollama chat API](https://docs.ollama.com/api/chat)
