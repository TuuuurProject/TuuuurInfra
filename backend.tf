module "backend_mig" {
  source = "./modules/mig"
  name   = "tuuur-backend"
  zone   = module.global_settings.zone
  subnet = module.snet_backend.object_id
  tags   = ["backend"]
  port   = 8080
  port_name = "http"
  machine_type = "e2-medium"
  image = "ubuntu-os-cloud/ubuntu-2204-lts"
  assign_public_ip = false
  min_size = 1
  max_size = 10
  service_account_email = module.sa_app.iam_email
  metadata = {
    startup-script = <<-EOT
      #!/bin/bash
      apt-get update
      apt-get install -y nodejs npm
      cat >/opt/app.js <<'JS'
      const http = require('http');
      const server = http.createServer((req, res) => {
        if (req.url === '/health') {res.writeHead(200); return res.end('ok');}
        res.end('backend ok');
      });
      server.listen(8080);
      JS
      nohup node /opt/app.js &
    EOT
  }
}
