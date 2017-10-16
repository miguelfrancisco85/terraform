// Configure the Google Cloud provider
provider "google" {
  credentials = "${file("account.json")}"
  project     = "support-sbt-mig"
  region      = "us-central1"
}


resource "google_compute_instance" "default" {
  name         = "jenkins"
  machine_type = "n1-standard-1"
  zone         = "us-central1-a"

  tags = ["foo", "bar", "jenkins-node"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  // Local SSD disk
  scratch_disk {
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }

  metadata {
    foo = "bar"
  }

  metadata_startup_script = <<SCRIPT
  wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key > /tmp/jenkins
  sudo apt-key add /tmp/jenkins
  echo "deb https://pkg.jenkins.io/debian-stable binary/" >> /etc/apt/sources.list
  sudo apt-get update
  sudo apt install -y apt-transport-https
  sudo apt-get update
  sudo apt-get install -y jenkins
  mkdir -p /var/lib/jenkins/init.groovy.d/

cat <<EOF > /var/lib/jenkins/init.groovy.d/basic-security.groovy
#!groovy

import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

println "--> creating local user 'admin'"

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount('admin','admin')
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
instance.setAuthorizationStrategy(strategy)
instance.save()
EOF
sudo service jenkins restart
  SCRIPT

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }
}

resource "google_compute_firewall" "default" {
    name = "tf-jenkins"
    network = "default"

    allow {
        protocol = "tcp"
        ports = ["8080"]
    }

    source_ranges = ["0.0.0.0/0"]
    target_tags = ["jenkins-node"]
}
