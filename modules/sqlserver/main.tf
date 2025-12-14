locals {
  use_cloudsql = var.mode == "cloudsql"
}

# -------- Cloud SQL for SQL Server (Private IP) --------
resource "google_sql_database_instance" "sql" {
  count            = local.use_cloudsql ? 1 : 0
  name             = "${var.name_prefix}-sql"
  region           = var.region
  database_version = var.database_version
  root_password    = var.root_password

  # Force destruction avant Service Networking Connection
  depends_on = [var.service_networking_connection]

  settings {
    tier              = var.tier
    availability_type = var.high_availability ? "REGIONAL" : "ZONAL"
    disk_size         = var.disk_size_gb
    disk_type         = var.disk_type

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_self_link
    }

    backup_configuration {
      enabled = true
    }

    user_labels = var.labels
  }

  deletion_protection = false
}

resource "google_sql_database" "db" {
  count    = local.use_cloudsql ? 1 : 0
  name     = var.db_name
  instance = google_sql_database_instance.sql[0].name
}

resource "google_sql_user" "user" {
  count    = local.use_cloudsql ? 1 : 0
  name     = var.db_user
  instance = google_sql_database_instance.sql[0].name
  password = var.db_password
  type     = "BUILT_IN"
}

# -------- Migration automatique via Cloud Run Job --------

# Service Account pour les Cloud Run Jobs
resource "google_service_account" "db_setup_job" {
  count        = local.use_cloudsql && var.run_migration && var.migration_image != "" ? 1 : 0
  account_id   = "${var.name_prefix}-db-setup"
  display_name = "Service Account for SQL Database Setup Job"
  project      = var.project_id
}

# Cloud Run Job pour configurer l'utilisateur dans la base de données
# Ce job utilise le compte root (sqlserver) pour créer l'utilisateur avec les bonnes permissions
resource "google_cloud_run_v2_job" "db_setup" {
  count    = local.use_cloudsql && var.run_migration && var.migration_image != "" ? 1 : 0
  provider = google-beta

  name     = "${var.name_prefix}-db-setup"
  location = var.region
  project  = var.project_id

  deletion_protection = false

  labels = var.labels

  template {
    task_count = 1

    template {
      timeout         = "600s" # 10 minutes max
      service_account = google_service_account.db_setup_job[0].email
      max_retries     = 1

      # VPC Access pour connexion privée à Cloud SQL
      dynamic "vpc_access" {
        for_each = var.vpc_connector_id != null ? [1] : []
        content {
          connector = var.vpc_connector_id
          egress    = "PRIVATE_RANGES_ONLY"
        }
      }

      containers {
        # Utiliser l'image Python avec pymssql pour exécuter les commandes SQL
        image = "python:3.11-slim"

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }

        # Script Python pour configurer l'utilisateur
        command = ["/bin/bash"]
        args = [
          "-c",
          <<-EOT
            set -e
            echo "Starting database user setup..."
            
            # Installer pymssql
            pip install --quiet pymssql
            
            # Attendre que la base soit accessible
            echo "Waiting for database to be ready..."
            sleep 10
            
            # Script Python pour configurer l'utilisateur
            python3 << 'PYTHON'
import pymssql
import os
import sys

def setup_user():
    db_server = os.environ['DB_SERVER']
    db_name = os.environ['DB_NAME']
    db_user = os.environ['DB_USER']
    root_password = os.environ['ROOT_PASSWORD']
    
    print(f"Connecting to {db_server} as sqlserver...")
    
    try:
        # Connexion à master avec le compte root
        conn = pymssql.connect(
            server=db_server,
            user='sqlserver',
            password=root_password,
            database='master'
        )
        cursor = conn.cursor()
        
        # Vérifier que le login existe
        print(f"Checking if login {db_user} exists...")
        cursor.execute(f"SELECT name FROM sys.server_principals WHERE name = '{db_user}'")
        if not cursor.fetchone():
            print(f"ERROR: Login {db_user} does not exist!")
            sys.exit(1)
        print(f"Login {db_user} exists - OK")
        
        # Fermer la connexion à master
        cursor.close()
        conn.close()
        
        # Connexion à la base de données cible
        print(f"Connecting to database {db_name}...")
        conn = pymssql.connect(
            server=db_server,
            user='sqlserver',
            password=root_password,
            database=db_name
        )
        cursor = conn.cursor()
        
        # Créer l'utilisateur dans la base de données s'il n'existe pas
        print(f"Creating user {db_user} in database {db_name}...")
        cursor.execute(f"SELECT name FROM sys.database_principals WHERE name = '{db_user}'")
        if not cursor.fetchone():
            cursor.execute(f"CREATE USER [{db_user}] FOR LOGIN [{db_user}]")
            print(f"User {db_user} created successfully")
        else:
            print(f"User {db_user} already exists")
        
        # Ajouter au rôle db_owner
        print(f"Adding {db_user} to db_owner role...")
        cursor.execute(f"ALTER ROLE db_owner ADD MEMBER [{db_user}]")
        
        # Permissions explicites
        print(f"Granting explicit permissions to {db_user}...")
        cursor.execute(f"GRANT CONNECT TO [{db_user}]")
        cursor.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE TO [{db_user}]")
        cursor.execute(f"GRANT CREATE TABLE, CREATE VIEW, CREATE PROCEDURE TO [{db_user}]")
        cursor.execute(f"GRANT EXECUTE TO [{db_user}]")
        cursor.execute(f"GRANT ALTER ON SCHEMA::dbo TO [{db_user}]")
        
        conn.commit()
        cursor.close()
        conn.close()
        
        print("")
        print("=" * 50)
        print(f"SUCCESS: User {db_user} configured with db_owner permissions!")
        print("=" * 50)
        
    except Exception as e:
        print(f"ERROR: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    setup_user()
PYTHON
            
            echo "Database user setup completed successfully!"
          EOT
        ]

        env {
          name  = "DB_SERVER"
          value = google_sql_database_instance.sql[0].private_ip_address
        }

        env {
          name  = "DB_NAME"
          value = var.db_name
        }

        env {
          name  = "DB_USER"
          value = var.db_user
        }

        env {
          name  = "ROOT_PASSWORD"
          value = var.root_password
        }
      }
    }
  }

  depends_on = [
    google_sql_database.db,
    google_sql_user.user
  ]
}

# Service Account pour le Cloud Run Job de migration
resource "google_service_account" "migration_job" {
  count        = local.use_cloudsql && var.run_migration && var.migration_image != "" ? 1 : 0
  account_id   = "${var.name_prefix}-db-migration"
  display_name = "Service Account for SQL Database Migration Job"
  project      = var.project_id
}

# Cloud Run Job pour exécuter la migration SQL (sqlpackage DACPAC)
resource "google_cloud_run_v2_job" "db_migration" {
  count    = local.use_cloudsql && var.run_migration && var.migration_image != "" ? 1 : 0
  provider = google-beta

  name     = "${var.name_prefix}-db-migration"
  location = var.region
  project  = var.project_id

  deletion_protection = false

  labels = var.labels

  template {
    task_count = 1

    template {
      timeout         = "1800s" # 30 minutes max
      service_account = google_service_account.migration_job[0].email

      max_retries = 1

      # VPC Access pour connexion privée à Cloud SQL
      dynamic "vpc_access" {
        for_each = var.vpc_connector_id != null ? [1] : []
        content {
          connector = var.vpc_connector_id
          egress    = "PRIVATE_RANGES_ONLY"
        }
      }

      containers {
        image = var.migration_image

        resources {
          limits = {
            cpu    = "2"
            memory = "2Gi"
          }
        }

        # Variables d'environnement pour sqlpackage
        # Utiliser le compte root pour éviter les problèmes de DROP USER
        env {
          name  = "DB_SERVER"
          value = google_sql_database_instance.sql[0].private_ip_address
        }

        env {
          name  = "DB_NAME"
          value = var.db_name
        }

        env {
          name  = "DB_USER"
          value = "sqlserver"
        }

        env {
          name  = "DB_PASSWORD"
          value = var.root_password
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image, # Ignorer les changements d'image après création
    ]
  }

  depends_on = [
    google_sql_database.db,
    google_sql_user.user
  ]
}

# Exécution automatique : Setup puis Migration
resource "null_resource" "run_db_setup_and_migration" {
  count = local.use_cloudsql && var.run_migration && var.migration_image != "" ? 1 : 0

  triggers = {
    setup_job_id     = google_cloud_run_v2_job.db_setup[0].id
    migration_job_id = google_cloud_run_v2_job.db_migration[0].id
    db_password      = var.db_password
    root_password    = var.root_password
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting 30 seconds for Cloud SQL instance to be fully ready..."
      sleep 30
      
      echo "=========================================="
      echo "Step 1: Running database migration with root user..."
      echo "=========================================="
      gcloud run jobs execute ${google_cloud_run_v2_job.db_migration[0].name} \
        --region=${var.region} \
        --project=${var.project_id} \
        --wait
      
      if [ $? -eq 0 ]; then
        echo "✓ Database migration completed successfully!"
        echo ""
        echo "=========================================="
        echo "Step 2: Setting up appuser permissions after migration..."
        echo "=========================================="
        gcloud run jobs execute ${google_cloud_run_v2_job.db_setup[0].name} \
          --region=${var.region} \
          --project=${var.project_id} \
          --wait
        
        if [ $? -eq 0 ]; then
          echo "✓ Database user setup completed successfully!"
        else
          echo "✗ Database user setup failed. Check logs with:"
          echo "  gcloud run jobs executions list --job=${google_cloud_run_v2_job.db_setup[0].name} --region=${var.region}"
          exit 1
        fi
      else
        echo "✗ Database migration failed. Check logs with:"
        echo "  gcloud run jobs executions list --job=${google_cloud_run_v2_job.db_migration[0].name} --region=${var.region}"
        exit 1
      fi
      
      echo ""
      echo "=========================================="
      echo "✓ All database operations completed!"
      echo "=========================================="
    EOT

    environment = {
      CLOUDSDK_CORE_PROJECT = var.project_id
    }
  }

  depends_on = [
    google_cloud_run_v2_job.db_setup,
    google_cloud_run_v2_job.db_migration
  ]
}
