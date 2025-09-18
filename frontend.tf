module "frontend_mig" {
  source = "./modules/mig"
  name   = "tuuur-frontend"
  zone   = module.global_settings.zone
  subnet = module.snet_frontend.object_id
  tags   = ["frontend"]
  port   = 80
  min_size = 2
  max_size = 10
  assign_public_ip = true
  service_account_email = module.sa_app.iam_email
  metadata = {
    startup-script = <<-EOT
      #!/bin/bash
      apt-get update
      apt-get install -y nginx
      echo '<h1>Tuuur Frontend</h1>' > /var/www/html/index.html
      echo 'ok' > /var/www/html/health
    EOT
  }
}
