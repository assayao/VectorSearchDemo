# Terraform Orchestration

This Terraform stack provisions the cloud side of the vector-search demo.

Default path:

1. Create an Oracle Autonomous AI Database Always Free instance.
2. Optionally generate a wallet zip for local/manual clients.
3. Optionally create an Always Free eligible Ampere A1 VM for the FastAPI/Ollama runtime.

Existing DB path:

Set `create_autonomous_database = false`, skip wallet generation, and point the app `.env` to your existing Oracle or PostgreSQL/pgvector database.

## Prerequisites

- Terraform compatible with your OCI Resource Manager stack version, or a recent local Terraform CLI if you are running outside RM
- OCI CLI/config at `~/.oci/config`, or equivalent OCI provider environment variables
- An OCI home region that supports Always Free Autonomous AI Database with `26ai` if you want native vector search

## Run

```powershell
cd VectorDemoStack
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

For OCI Resource Manager, upload this folder as the stack source and prefer the RM Variables tab for real secret values instead of storing them in `terraform.tfvars`.

After apply, update the root `.env` for local runs:

```text
VECTOR_DB=oracle
ORACLE_USER=admin
ORACLE_PASSWORD=<autonomous_db_admin_password>
ORACLE_DSN=<TLS connection string or wallet alias>
ORACLE_WALLET_LOCATION=<unzipped wallet folder when using mTLS>
ORACLE_WALLET_PASSWORD=<wallet password when using mTLS>
```

Create the vector table:

```powershell
sqlplus admin/<password>@<service_name> @../sql/oracle_schema.sql
```

Then run the API from the repository root:

```powershell
uvicorn vector_demo.api:app --reload
```

## Optional API VM

Set `enable_api_vm = true` to create:

- VCN
- public subnet
- internet gateway
- security rules for SSH and FastAPI port `8000`
- Ampere A1 flex VM
- optionally a reserved public IP created by the stack

The VM cloud-init installs Python, Git, Ollama, and pulls:

- `nomic-embed-text`
- `llama3.2`

If `api_repo_url` is set, the VM also:

- clones the repo
- writes `.env`
- initializes the Oracle schema
- creates a `systemd` service for FastAPI
- starts the app
- optionally calls `/ingest` on first boot

Recommended settings for a public demo:

```hcl
enable_api_vm             = true
api_repo_url              = "https://github.com/your-org/your-repo.git"
api_repo_ref              = "main"
require_mtls_connections  = false
create_reserved_public_ip = true
auto_ingest_on_boot       = true
```

For a public demo, restrict `ssh_cidr` and `api_cidr` to your IP range instead of `0.0.0.0/0`.

## Notes

- Always Free Autonomous DB creation uses `is_free_tier = true`.
- `autonomous_db_version = "26ai"` is recommended for vector search in supported Always Free home regions. Set it to `null` only if your tenancy cannot create that version and you plan to use an existing vector-capable database.
- For zero-touch VM deployment, `require_mtls_connections = false` avoids pushing a wallet through cloud-init and keeps the bootstrap path much simpler.
- If you choose mTLS, treat wallet outputs and Terraform state as sensitive.
