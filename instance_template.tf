resource "google_compute_instance_template" "backend_template" {
  name        = "tuuur-backend-tpl"
  description = "Template VM backend Tuuur"
  tags        = ["backend"]

  machine_type   = "e2-medium"
  region         = module.global_settings.region
  can_ip_forward = false

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2004-lts"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = module.snet_backend.object_id
    # No external IP for backend VMs
  }

  metadata = {
    ssh-keys = "user:${file("~/.ssh/id_ed25519.pub")}"
    startup-script = <<-EOT
      #!/usr/bin/env bash
      set -euxo pipefail
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y nodejs npm
      cat >/opt/app.js <<'JS'
      const http = require('http');
      const server = http.createServer((req, res) => {
        if (req.url === '/health') {
          res.writeHead(200, {'Content-Type': 'text/plain'});
          return res.end('ok');
        }
        res.writeHead(200, {'Content-Type': 'application/json'});
        res.end(JSON.stringify({service:'tuuur-backend', ok:true, time: new Date().toISOString()}));
      });
      server.listen(8080, '0.0.0.0', () => console.log('backend on 8080'));
      JS
      nohup node /opt/app.js >/var/log/backend.log 2>&1 &
    EOT
  }

  service_account {
    email  = module.sa_app.iam_email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance_template" "frontend_template" {
  name        = "tuuur-frontend-tpl"
  description = "Template VM frontend Tuuur"
  tags        = ["frontend"]

  machine_type   = "e2-medium"
  region         = module.global_settings.region
  can_ip_forward = false

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2004-lts"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork   = module.snet_frontend.object_id
    access_config {} # public IP for LB health checks if needed
  }

  metadata = {
    ssh-keys = "user:${file("~/.ssh/id_ed25519.pub")}"
    startup-script = <<-EOT
      #!/usr/bin/env bash
      set -euxo pipefail
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y nginx curl
      cat >/var/www/html/index.html <<'HTML'
      <html><head><title>Tuuur</title></head>
      <body style="font-family: sans-serif">
        <h1>Tuuur — Quiz de culture générale</h1>
        <p>Frontend OK</p>
        <p><a href="/health">Health</a></p>
      </body></html>
      HTML
      cat >/var/www/html/health <<'TXT'
      ok
      TXT
      systemctl restart nginx
    EOT
  }

  service_account {
    email  = module.sa_app.iam_email
    scopes = ["cloud-platform"]
  }
}
