module "sql" {
  source                  = "./modules/sql"
  sql_instance_name       = "tuuur-sql"
  sql_instance_region     = module.global_settings.region
  sql_database_name       = "tuuur_db"
  sql_user_name           = "tuuur_user"
  # Pour un démarrage sécurisé, aucun réseau autorisé par défaut.
  # Ajoutez vos IPs via sql_authorized_networks si nécessaire.
  sql_authorized_networks = []
}

# Stocker le mot de passe de l'utilisateur SQL dans Secret Manager
module "db_password_secret" {
  source       = "./modules/secret_manager"
  secret_name  = "tuuur-sql-user-password"
  secret_value = module.sql.sql_user_password
  labels       = { app = "tuuur", component = "db" }
}
