terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token  = "y0_AgAEA7qkdOJtAATuwQAAAAEZ7ggxAAAgbD_1N9JB45aoC0hDzG5apPARqA"
  cloud_id  = "b1g0r2kida4942eldbsv"
  folder_id = "b1gdajv7q25f1e3g4umo"
  zone  = "ru-central1-a"
}

resource "yandex_vpc_network" "network" {
  name = "jmix-network"
}

resource "yandex_vpc_subnet" "subnet" {
  name = "jmix-subnet"
  zone = "ru-central1-a"
  network_id = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_vpc_security_group" "sg" {
  name = "jmix-sg"
  network_id  = yandex_vpc_network.network.id

  ingress {
    protocol = "TCP"
    port = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "TCP"
    port = 8080
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "yandex_compute_instance" "vm" {
  name        = "jmix-vm"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      size     = 20
      type     = "network-ssd"
      image_id = "fd827b91d99psvq5fjit" # Ubuntu 22.04 LTS
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.subnet.id
    nat = true
    security_group_ids = [yandex_vpc_security_group.sg.id]
  }

  metadata = {
    user-data = <<-EOT
      #cloud-config
      users:
        - name: ipiris
          ssh-authorized-keys:
            - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDnIGeob8yS7NoSXpmtf2+/SJdIdQBgbtfLiiAYsJPxWDquajv/nSb4vAug7HGFFQu5+7a3LojXzoExgW4JF4BYAktNSXffYBL/9fJmO3pkRkj75e1jn2dLCqH3icoyZeGXFZhCwPg9C64BbIuTGLZjEPqLzqfMd/32fnqF/gZQHxVRVKor1Zne9FmaC2kW8Wf9t4lzoXfB8hiJFWprT8hMpZcBJRyZFH5smH5i0hJjsX4PMJ06NaocQzx4iuUtxUoIH6qSSNDZ26T+f5jAwkHeL3fFFW9xfbqPR6tlGMIkSp4/ECbOrO/LKwXGgqiuw3qbo7DRDDv80Ma6/bk1SJRb dmitry@DESKTOP-6HD43NJ
          sudo: ['ALL=(ALL) NOPASSWD:ALL']
          groups: [sudo, docker]
          shell: /bin/bash
      packages:
        - docker.io
      runcmd:
        - systemctl enable docker
        - systemctl start docker
        - docker pull jmix/jmix-bookstore
        - docker run -d --name bookstore -p 8080:8080 jmix/jmix-bookstore
    EOT
  }
}
