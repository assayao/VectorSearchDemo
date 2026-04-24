locals {
  target_compartment_id = trimspace(var.compartment_ocid) != "" ? var.compartment_ocid : var.compartment_id
  generate_wallet       = var.create_autonomous_database && trimspace(var.autonomous_db_wallet_password) != ""
  app_oracle_dsn        = var.create_autonomous_database ? oci_database_autonomous_database.vectordb[0].connection_strings[0].high : var.oracle_dsn
  app_wallet_zip_base64 = var.require_mtls_connections ? (var.create_autonomous_database ? (local.generate_wallet ? oci_database_autonomous_database_wallet.vectordb[0].content : "") : var.oracle_wallet_zip_base64) : var.oracle_wallet_zip_base64

  common_tags = {
    project = "ai-vector-db-demo"
  }
}

resource "oci_database_autonomous_database" "vectordb" {
  count = var.create_autonomous_database ? 1 : 0

  compartment_id              = local.target_compartment_id
  db_name                     = var.autonomous_db_name
  display_name                = var.autonomous_db_display_name
  admin_password              = var.autonomous_db_admin_password
  db_workload                 = var.autonomous_db_workload
  db_version                  = var.autonomous_db_version
  is_free_tier                = true
  is_mtls_connection_required = var.require_mtls_connections
  freeform_tags               = local.common_tags
}

resource "oci_database_autonomous_database_wallet" "vectordb" {
  count = local.generate_wallet ? 1 : 0

  autonomous_database_id = oci_database_autonomous_database.vectordb[0].id
  password               = var.autonomous_db_wallet_password
  base64_encode_content  = true
  generate_type          = "SINGLE"

  lifecycle {
    precondition {
      condition     = !var.require_mtls_connections || trimspace(var.autonomous_db_wallet_password) != ""
      error_message = "autonomous_db_wallet_password must be set when require_mtls_connections = true."
    }
  }
}

resource "local_sensitive_file" "wallet_zip" {
  count = local.generate_wallet && trimspace(var.wallet_output_path) != "" ? 1 : 0

  filename       = var.wallet_output_path
  content_base64 = oci_database_autonomous_database_wallet.vectordb[0].content
}

data "oci_identity_availability_domains" "ads" {
  count = var.enable_api_vm ? 1 : 0

  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu" {
  count = var.enable_api_vm ? 1 : 0

  compartment_id           = local.target_compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = var.api_image_os_version
  shape                    = var.api_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "oci_core_vnic_attachments" "api" {
  count = var.enable_api_vm && var.create_reserved_public_ip ? 1 : 0

  compartment_id = local.target_compartment_id
  instance_id    = oci_core_instance.api[0].id
}

data "oci_core_vnic" "api" {
  count = var.enable_api_vm && var.create_reserved_public_ip ? 1 : 0

  vnic_id = data.oci_core_vnic_attachments.api[0].vnic_attachments[0].vnic_id
}

data "oci_core_private_ips" "api" {
  count = var.enable_api_vm && var.create_reserved_public_ip ? 1 : 0

  vnic_id = data.oci_core_vnic.api[0].id
}

resource "oci_core_vcn" "api" {
  count = var.enable_api_vm ? 1 : 0

  compartment_id = local.target_compartment_id
  display_name   = "${var.api_vm_name}-vcn"
  cidr_block     = "10.42.0.0/16"
  dns_label      = "aivectordemo"
  freeform_tags  = local.common_tags
}

resource "oci_core_internet_gateway" "api" {
  count = var.enable_api_vm ? 1 : 0

  compartment_id = local.target_compartment_id
  display_name   = "${var.api_vm_name}-igw"
  vcn_id         = oci_core_vcn.api[0].id
  enabled        = true
  freeform_tags  = local.common_tags
}

resource "oci_core_route_table" "api" {
  count = var.enable_api_vm ? 1 : 0

  compartment_id = local.target_compartment_id
  display_name   = "${var.api_vm_name}-rt"
  vcn_id         = oci_core_vcn.api[0].id
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.api[0].id
  }
}

resource "oci_core_security_list" "api" {
  count = var.enable_api_vm ? 1 : 0

  compartment_id = local.target_compartment_id
  display_name   = "${var.api_vm_name}-security"
  vcn_id         = oci_core_vcn.api[0].id
  freeform_tags  = local.common_tags

  ingress_security_rules {
    protocol = "6"
    source   = var.ssh_cidr

    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = var.api_cidr

    tcp_options {
      min = 8000
      max = 8000
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_subnet" "api" {
  count = var.enable_api_vm ? 1 : 0

  compartment_id             = local.target_compartment_id
  display_name               = "${var.api_vm_name}-subnet"
  vcn_id                     = oci_core_vcn.api[0].id
  cidr_block                 = "10.42.1.0/24"
  route_table_id             = oci_core_route_table.api[0].id
  security_list_ids          = [oci_core_security_list.api[0].id]
  prohibit_public_ip_on_vnic = false
  dns_label                  = "api"
  freeform_tags              = local.common_tags
}

resource "oci_core_instance" "api" {
  count = var.enable_api_vm ? 1 : 0

  availability_domain = data.oci_identity_availability_domains.ads[0].availability_domains[0].name
  compartment_id      = local.target_compartment_id
  display_name        = var.api_vm_name
  shape               = var.api_shape
  freeform_tags       = local.common_tags

  shape_config {
    ocpus         = var.api_ocpus
    memory_in_gbs = var.api_memory_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.api[0].id
    assign_public_ip = var.create_reserved_public_ip ? false : true
    display_name     = "${var.api_vm_name}-vnic"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu[0].images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/templates/cloud-init-api.yaml.tftpl", {
      api_repo_url             = var.api_repo_url
      api_repo_ref             = var.api_repo_ref
      oracle_user              = var.oracle_user
      oracle_password          = var.autonomous_db_admin_password
      oracle_dsn               = local.app_oracle_dsn
      oracle_wallet_password   = var.autonomous_db_wallet_password
      oracle_wallet_zip_base64 = local.app_wallet_zip_base64
      embed_model              = "nomic-embed-text"
      chat_model               = "llama3.2"
      chunk_size               = 1200
      chunk_overlap            = 200
      app_port                 = var.app_port
      auto_ingest_on_boot      = var.auto_ingest_on_boot
      pdf_filename             = var.pdf_filename
    }))
  }

  lifecycle {
    precondition {
      condition     = trimspace(var.api_repo_url) != ""
      error_message = "api_repo_url must be set when enable_api_vm = true so the VM can clone and deploy the application."
    }

    precondition {
      condition     = var.create_autonomous_database || trimspace(var.oracle_dsn) != ""
      error_message = "When create_autonomous_database = false and enable_api_vm = true, set oracle_dsn."
    }

    precondition {
      condition     = !var.require_mtls_connections || trimspace(var.autonomous_db_wallet_password) != ""
      error_message = "Set autonomous_db_wallet_password when require_mtls_connections = true and enable_api_vm = true."
    }

    precondition {
      condition     = !var.require_mtls_connections || var.create_autonomous_database || trimspace(var.oracle_wallet_zip_base64) != ""
      error_message = "When require_mtls_connections = true and create_autonomous_database = false, set oracle_wallet_zip_base64."
    }
  }
}

resource "oci_core_public_ip" "api_reserved" {
  count = var.enable_api_vm && var.create_reserved_public_ip ? 1 : 0

  compartment_id = local.target_compartment_id
  display_name   = var.api_public_ip_display_name
  lifetime       = "RESERVED"
  private_ip_id  = data.oci_core_private_ips.api[0].private_ips[0].id
  freeform_tags  = local.common_tags
}
