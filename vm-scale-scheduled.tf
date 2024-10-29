# Объявление переменных для конфиденциальных параметров

variable "folder_id" {
  type = string
}

variable "username" {
  type = string
}

variable "ssh_key_path" {
  type = string
}

# Настройка провайдера

terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.47.0"
    }
  }
}

provider "yandex" {
  folder_id = var.folder_id
}

# Создание сервисного аккаунта и назначение ему ролей

resource "yandex_iam_service_account" "vm-scale-scheduled-sa" {
  name      = "vm-scale-scheduled-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "vm-scale-scheduled-sa-role-compute" {
  folder_id = var.folder_id
  role      = "compute.admin"
  member    = "serviceAccount:${yandex_iam_service_account.vm-scale-scheduled-sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "vm-scale-scheduled-sa-role-iam" {
  folder_id = var.folder_id
  role      = "iam.serviceAccounts.user"
  member    = "serviceAccount:${yandex_iam_service_account.vm-scale-scheduled-sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "vm-scale-scheduled-sa-role-functions" {
  folder_id = var.folder_id
  role      = "functions.functionInvoker"
  member    = "serviceAccount:${yandex_iam_service_account.vm-scale-scheduled-sa.id}"
}

# Создание облачной сети и подсетей

resource "yandex_vpc_network" "vm-scale-scheduled-network" {
  name = "vm-scale-scheduled-network"
}

resource "yandex_vpc_subnet" "vm-scale-scheduled-subnet-a" {
  name           = "vm-scale-scheduled-subnet-a"
  zone           = "ru-central1-a"
  v4_cidr_blocks = ["192.168.1.0/24"]
  network_id     = yandex_vpc_network.vm-scale-scheduled-network.id
}

resource "yandex_vpc_subnet" "vm-scale-scheduled-subnet-b" {
  name           = "vm-scale-scheduled-subnet-b"
  zone           = "ru-central1-b"
  v4_cidr_blocks = ["192.168.2.0/24"]
  network_id     = yandex_vpc_network.vm-scale-scheduled-network.id
}

# Создание образа

resource "yandex_compute_image" "vm-scale-scheduled-image" {
  source_family = "ubuntu-2004-lts"
}

# Создание группы ВМ

resource "yandex_compute_instance_group" "vm-scale-scheduled-ig" {
  name               = "vm-scale-scheduled-ig"
  service_account_id = yandex_iam_service_account.vm-scale-scheduled-sa.id

  allocation_policy {
    zones = [
      "ru-central1-a",
      "ru-central1-b"
    ]
  }

  instance_template {
    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = yandex_compute_image.vm-scale-scheduled-image.id
        size     = 15
      }
    }

    platform_id = "standard-v3"
    resources {
      cores         = 2
      core_fraction = 20
      memory        = 2
    }

    network_interface {
      network_id = yandex_vpc_network.vm-scale-scheduled-network.id
      subnet_ids = [
        yandex_vpc_subnet.vm-scale-scheduled-subnet-a.id,
        yandex_vpc_subnet.vm-scale-scheduled-subnet-b.id
      ]
    }

    metadata = {
      user-data = "#cloud-config\nusers:\n  - name: ${var.username}\n    groups: sudo\n    shell: /bin/bash\n    sudo: 'ALL=(ALL) NOPASSWD:ALL'\n    ssh_authorized_keys:\n      - ${file("${var.ssh_key_path}")}"
    }
  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  deploy_policy {
    max_unavailable = 2
    max_creating    = 2
    max_expansion   = 2
    max_deleting    = 2
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.vm-scale-scheduled-sa-role-compute,
    yandex_resourcemanager_folder_iam_member.vm-scale-scheduled-sa-role-iam
  ]
}

# Создание функции

resource "yandex_function" "vm-scale-scheduled-function" {
  name               = "vm-scale-scheduled-function"
  runtime            = "bash"

  user_hash          = "function-v1"
  entrypoint         = "handler.sh"
  content {
    zip_filename = "vm-scale-scheduled-function.zip"
  }

  execution_timeout  = "60"
  memory             = "128"
  service_account_id = yandex_iam_service_account.vm-scale-scheduled-sa.id

  environment = {
    IG_NAME      = yandex_compute_instance_group.vm-scale-scheduled-ig.name
    IG_BASE_SIZE = "2"
    FOLDER_ID    = var.folder_id
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.vm-scale-scheduled-sa-role-functions
  ]
}

# Создание тригера

resource "yandex_function_trigger" "vm-scale-scheduled-trigger" {
  name = "vm-scale-scheduled-trigger"
  timer {
    cron_expression = "*/2 * * * ? *"
  }
  function {
    id                 = yandex_function.vm-scale-scheduled-function.id
    tag                = "$latest"
    service_account_id = yandex_iam_service_account.vm-scale-scheduled-sa.id
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.vm-scale-scheduled-sa-role-functions
  ]
}
