resource "null_resource" "demo" {
  triggers = {
    google_storage_bucket = google_storage_bucket.bucket.name
    credentials           = md5(google_service_account_key.key.private_key)
    encryption_key        = md5(random_id.encryption-key.b64_std)
  }

  depends_on = [
    google_project_iam_member.service-account,
    google_storage_bucket_iam_member.sa-to-bucket,
  ]

  provisioner "local-exec" {
    command = <<EOF
rm -rf ../demo
mkdir -p ../demo

cat > ../demo/credentials.json <<"EOH"
${base64decode(google_service_account_key.key.private_key)}
EOH

cat > ../demo/.gitignore <<"EOH"
.terraform
credentials.json
env.sh
terraform.tfstate*
EOH

cat > ../demo/env.sh <<"EOH"
export GOOGLE_ENCRYPTION_KEY="${random_id.encryption-key.b64_std}"
export GOOGLE_CREDENTIALS="credentials.json"
export GOOGLE_PROJECT="${google_project.project.name}"
EOH

cat > ../demo/state.tf <<"EOH"
terraform {
  backend "gcs" {
    bucket = "${google_storage_bucket.bucket.name}"
  }
}
EOH

cat > ../demo/main.tf <<"EOH"
resource "google_compute_firewall" "default" {
  name    = "demo-firewall"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["web"]
}

resource "google_compute_instance" "default" {
  name         = "demo"
  machine_type = "n1-highcpu-2"
  zone         = "us-east4-b"

  can_ip_forward            = "true"
  allow_stopping_for_update = "true"

  tags = ["web"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network       = "default"
    access_config = {}
  }

  metadata_startup_script = "sudo apt-get update && sudo apt-get install -yqq nginx"
}

output "address" {
  value = "$${google_compute_instance.default.network_interface.0.access_config.0.assigned_nat_ip}"
}
EOH

cd ../demo

GOOGLE_ENCRYPTION_KEY="${random_id.encryption-key.b64_std}" \
GOOGLE_CREDENTIALS="credentials.json" \
GOOGLE_PROJECT="${google_project.project.name}" \
terraform init

rm -rf .git
git init
git remote add origin ${github_repository.repo.http_clone_url}
git add .
git commit -m "Initial commit"
git push -u -f origin master
EOF

  }
}

