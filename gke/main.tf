# VPC
# ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-vpc"
  auto_create_subnetworks = "false"
}

# Subnet
# ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_id}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "192.168.10.0/24"
  # this cluster can have up to 252 nodes and about 27220 (252*110) pods
  # this cluster require atleast a /17 cidr secondary ip address range for pods
  secondary_ip_range {
    range_name    = "${var.project_id}-pod-range"
    ip_cidr_range = "10.10.0.0/16"
  }
  secondary_ip_range {
    range_name    = "${var.project_id}-svc-range"
    ip_cidr_range = "10.11.0.0/16"
  }
}

#SA
resource "google_service_account" "default" {
  account_id   = "service-account-id"
  display_name = "Service Account"
}

# GKE
resource "google_container_cluster" "primary" {
  name     = "my-gke-cluster"
  location = "us-central1"
  # If you specify a zone (such as us-central1-a), the cluster will be a zonal cluster with a single cluster master.
  # If you specify a region (such as us-west1) he cluster will be a regional cluster with multiple masters spread across zones in the region,
  # and with default node locations in those zones as well

  # A "multi-zonal" cluster is a zonal cluster with at least one additional zone defined;
  # in a multi-zonal cluster, the cluster master is only present in a single zone while nodes are present in each of the primary zone and the node locations.
  # In contrast, in a regional cluster, cluster master nodes are present in multiple zones in the region.
  # For that reason, regional clusters should be preferred.

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection = false
  network = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  addons_config {
    network_policy_config {
      # enabling network policy
      disabled = false
    }
    gcp_filestore_csi_driver_config {
      enabled = false
    }
    gcs_fuse_csi_driver_config {
      enabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = false
    }
    gke_backup_agent_config {
      enabled = false
    }
  }

  cluster_autoscaling {
    enabled = true

    resource_limits {
      resource_type = cpu
      minimum = 1
      maximum = 10
    }
    resource_limits {
      resource_type = memory
      minimum = 1
      maximum = 64
    }

    auto_provisioning_defaults {
      service_account = google_service_account.default.email
      oauth_scopes    = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
      disk_size = 10
      disk_type = "pd-standard"
      # the value must be one of the [COS_CONTAINERD, COS, UBUNTU_CONTAINERD, UBUNTU]
      # NOTE : COS AND UBUNTU are deprecated as of GKE 1.24
      image_type = "COS_CONTAINERD"
      management {
        auto_upgrade = true
        auto_repair = true
      }
      upgrade_settings {
          strategy = "SURGE"
          # The maximum number of nodes that can be created beyond the current size of the node pool during the upgrade process
          max_surge = 2
          # The maximum number of nodes that can be simultaneously unavailable during the upgrade process
          max_unavailable = 2
        }
    }
  }
  # https://cloud.google.com/kubernetes-engine/docs/concepts/node-auto-provisioning
  # For node auto-provisioning to work as expected, Pod resource requests need to be large enough for the Pod to function normally.
  # If resource requests are too small, auto-provisioned nodes might not have the resources to launch pods.
  
  enable_autopilot = "false"
  networking_mode = "VPC_NATIVE"

  logging_config {
    enable_components = [ SYSTEM_COMPONENTS, APISERVER, CONTROLLER_MANAGER, SCHEDULER, WORKLOADS ]
  }
  logging_service = "logging.googleapis.com/kubernetes"

  monitoring_config {
    enable_components = [ SYSTEM_COMPONENTS, APISERVER, SCHEDULER, CONTROLLER_MANAGER, STORAGE, HPA, POD, DAEMONSET, DEPLOYMENT, STATEFULSET, KUBELET, CADVISOR, DCGM]
  }
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  maintenance_policy {
    recurring_window {
      start_time = "2019-01-01T00:00:00Z"
      end_time = "2019-01-02T00:00:00Z"
      recurrence = "FREQ=DAILY"
    }
    maintenance_exclusion{
      exclusion_name = "batch job"
      start_time = "2019-01-01T00:00:00Z"
      end_time = "2019-01-02T00:00:00Z"
      exclusion_options {
        scope = "NO_UPGRADES"
      }
    }
    maintenance_exclusion{
      exclusion_name = "holiday data load"
      start_time = "2019-05-01T00:00:00Z"
      end_time = "2019-05-02T00:00:00Z"
      exclusion_options {
        scope = "NO_MINOR_UPGRADES"
      }
    }
  }

  ip_allocation_policy {
    cluster_secondary_range_name = google_compute_subnetwork.subnet.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.subnet.secondary_ip_range[1].range_name
  }

  network_policy {
    enabled = false
  }

  private_cluster_config {
    enable_private_nodes = true
    enable_private_endpoint = false
  }

}

# Node Pool
resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "my-node-pool"
  location   = "us-central1"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

# It is recommended that node pools be created and managed as separate resources as in the example above. 
# This allows node pools to be added and removed without recreating the cluster. 
# Node pools defined directly in the google_container_cluster resource cannot be removed without re-creating the cluster.