# -----------------------------------------------------------------------------
# PostgreSQL Database (Managed DB Simulation)
# -----------------------------------------------------------------------------
module "postgresql" {
  source = "../../modules/postgresql"

  namespace    = "database"
  storage_size = var.db_storage_size

  credentials = {
    username = var.db_username
    password = var.db_password
    database = var.db_name
  }

  depends_on = [kind_cluster.this]
}

# Output connection string for services
output "database_url" {
  description = "PostgreSQL connection string"
  value       = module.postgresql.connection_string
  sensitive   = true
}
