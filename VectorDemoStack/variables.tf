variable "region" {
  description = "OCI home region for Always Free resources, for example us-ashburn-1."
  type        = string
}

variable "tenancy_ocid" {
  description = "Tenancy OCID. Used to discover availability domains for the optional API VM."
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment OCID where demo resources will be created. This name matches OCI Resource Manager auto-populated variables."
  type        = string
  default     = ""
}

variable "compartment_id" {
  description = "Backward-compatible alias for compartment_ocid."
  type        = string
  default     = ""
}

variable "oci_config_profile" {
  description = "Profile name from ~/.oci/config when running Terraform locally. Not used in OCI Resource Manager."
  type        = string
  default     = "DEFAULT"
}

variable "create_autonomous_database" {
  description = "Create a new Oracle Autonomous AI Database Always Free instance. Set false when using an existing DB."
  type        = bool
  default     = true
}

variable "autonomous_db_name" {
  description = "Autonomous DB name. Must be unique in the tenancy, alphanumeric, and start with a letter."
  type        = string
  default     = "AIVECTORDB"
}

variable "autonomous_db_display_name" {
  description = "Display name for the Autonomous DB."
  type        = string
  default     = "ai-vector-demo"
}

variable "autonomous_db_admin_password" {
  description = "ADMIN password for the Autonomous DB."
  type        = string
  sensitive   = true
}

variable "autonomous_db_wallet_password" {
  description = "Password used to encrypt the generated Autonomous DB wallet."
  type        = string
  sensitive   = true
}

variable "autonomous_db_version" {
  description = "Autonomous AI Database version. Use 26ai in supported Always Free home regions; set null to let OCI choose."
  type        = string
  default     = "26ai"
  nullable    = true
}

variable "autonomous_db_workload" {
  description = "Autonomous workload. OLTP is the best fit for this API demo."
  type        = string
  default     = "OLTP"

  validation {
    condition     = contains(["OLTP", "DW", "APEX", "LH"], var.autonomous_db_workload)
    error_message = "Use one of OLTP, DW, APEX, or LH. AJD is intentionally excluded because Always Free cannot use AJD with is_free_tier."
  }
}

variable "wallet_output_path" {
  description = "Optional local path for the generated wallet zip when running Terraform locally. Leave empty in OCI Resource Manager."
  type        = string
  default     = ""
}

variable "oracle_user" {
  description = "Database username used by the application."
  type        = string
  default     = "admin"
}

variable "oracle_dsn" {
  description = "Database service name to use when create_autonomous_database is false."
  type        = string
  default     = ""
}

variable "oracle_wallet_zip_base64" {
  description = "Optional base64-encoded wallet zip content to use when create_autonomous_database is false."
  type        = string
  sensitive   = true
  default     = ""
}

variable "require_mtls_connections" {
  description = "Require mTLS connections for the Autonomous Database. Set false for zero-touch VM deployment using TLS without a wallet."
  type        = bool
  default     = false
}

variable "enable_api_vm" {
  description = "Create an optional Always Free eligible Ampere A1 VM for the API/Ollama runtime."
  type        = bool
  default     = false
}

variable "api_vm_name" {
  description = "Name for the optional API VM."
  type        = string
  default     = "ai-vector-api"
}

variable "api_shape" {
  description = "Compute shape for the optional API VM. VM.Standard.A1.Flex is Always Free eligible subject to tenancy limits."
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "api_ocpus" {
  description = "OCPUs for the optional API VM."
  type        = number
  default     = 2
}

variable "api_memory_gbs" {
  description = "Memory in GB for the optional API VM."
  type        = number
  default     = 12
}

variable "api_image_os_version" {
  description = "Ubuntu image version for the optional API VM."
  type        = string
  default     = "22.04"
}

variable "ssh_public_key" {
  description = "SSH public key for the optional API VM."
  type        = string
  default     = ""
}

variable "ssh_cidr" {
  description = "CIDR allowed to SSH into the optional API VM."
  type        = string
  default     = "0.0.0.0/0"
}

variable "api_cidr" {
  description = "CIDR allowed to reach FastAPI on port 8000 on the optional API VM."
  type        = string
  default     = "0.0.0.0/0"
}

variable "api_repo_url" {
  description = "Git repository URL for this demo code."
  type        = string
  default     = ""
}

variable "api_repo_ref" {
  description = "Git branch, tag, or commit to check out on the VM."
  type        = string
  default     = "main"
}

variable "app_port" {
  description = "FastAPI listen port on the VM."
  type        = number
  default     = 8000
}

variable "auto_ingest_on_boot" {
  description = "When true, ingest the bundled PDF automatically after the service starts."
  type        = bool
  default     = true
}

variable "pdf_filename" {
  description = "PDF file expected in the application repository root."
  type        = string
  default     = "move-oracle-cloud-using-zero-downtime-migration.pdf"
}

variable "create_reserved_public_ip" {
  description = "Create and attach a reserved public IP to the API VM. This is the easiest fully automated way to keep a stable endpoint."
  type        = bool
  default     = false
}

variable "api_public_ip_display_name" {
  description = "Display name for a reserved public IP created by the stack."
  type        = string
  default     = "ai-vector-api-public-ip"
}
