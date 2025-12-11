module "sql" {
  source                      = "./modules/sql"
  sql_instance_name           = "tuuur-sqlserver"
  sql_instance_version        = "SQLSERVER_2022_STANDARD"
  sql_instance_region         = module.global_settings.region
  sql_tier                    = "db-custom-2-8192"
  sql_backup_enabled          = true
  sql_backup_start_time       = "03:00"
  sql_deletion_protection     = true
  sql_availability_type       = "ZONAL"
  sql_public_ip_enabled       = true
  sql_database_name           = "tuuur_db"
  sql_user_name               = "tuuuadmin"
  sql_authorized_networks     = []
}

# Stocker le mot de passe de l'utilisateur SQL dans Secret Manager
module "db_password_secret" {
  source       = "./modules/secret_manager"
  secret_name  = "tuuur-sql-user-password"
  secret_value = module.sql.sql_user_password
  labels       = { app = "tuuur", component = "db" }
}
