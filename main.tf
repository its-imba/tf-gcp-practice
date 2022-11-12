provider "google" {
  project = var.project
  region  = var.region
}

resource "google_compute_firewall" "firewall" {
  name    = "gritfy-firewall-externalssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"] # Not So Secure. Limit the Source Range
  target_tags   = ["externalssh"]
}

resource "google_compute_firewall" "webserverrule" {
  name    = "gritfy-webserver"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80","443"]
  }

  source_ranges = ["0.0.0.0/0"] # Not So Secure. Limit the Source Range
  target_tags   = ["webserver"]
}

# We create a public IP address for our google compute instance to utilize
resource "google_compute_address" "static" {
  name = "vm-public-address"
  project = var.project
  region = var.region
  depends_on = [ google_compute_firewall.firewall ]
}


resource "google_compute_instance" "dev" {
  name         = "devserver"
  machine_type = "f1-micro"
  zone         = "${var.region}-a"
  tags         = ["externalssh","webserver"]

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
    }
  }

  network_interface {
    network = "default"

    access_config {
      nat_ip = google_compute_address.static.address
    }
  }

  # Copy in the bash script we want to execute.
  # The source is the location of the bash script
  # on the local linux box you are executing terraform
  # from.  The destination is on the new AWS instance.
  provisioner "file" {
    source      = "/Users/samhiscox/tf-linux-gcp/docker-install.sh"
    destination = "/tmp/docker-install.sh"

    connection {
     host        = google_compute_address.static.address
     type        = "ssh"
     # username of the instance would vary for each account refer the OS Login in GCP documentation
     user        = var.user 
     timeout     = "500s"
     # private_key being used to connect to the VM. ( the public key was copied earlier using metadata )
     private_key = file(var.privatekeypath)
   }
  }
  # Change permissions on bash script and execute from ec2-user.
  provisioner "remote-exec" {

    connection {
     host        = google_compute_address.static.address
     type        = "ssh"
     # username of the instance would vary for each account refer the OS Login in GCP documentation
     user        = var.user 
     timeout     = "500s"
     # private_key being used to connect to the VM. ( the public key was copied earlier using metadata )
     private_key = file(var.privatekeypath)
   }

    inline = [
      "chmod +x /tmp/docker-install.sh",
      "sudo /tmp/docker-install.sh",
    ]
  }


  # Ensure firewall rule is provisioned before server, so that SSH doesn't fail.
  depends_on = [ google_compute_firewall.firewall, google_compute_firewall.webserverrule ]

  service_account {
    email  = var.email
    scopes = ["compute-ro"]
  }

  metadata = {
    ssh-keys = "${var.user}:${file(var.publickeypath)}"
  }

}
