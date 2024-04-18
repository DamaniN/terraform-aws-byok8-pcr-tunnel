# Note: This Terraform is meant to be run from a system that has network connectivity
# to the EKS cluster that it creates.

locals {
  # Convert cluster_connection_command to a list of variables
  tunnel_container_name = element(split(" ", module.polaris-aws-cloud-native-customer-managed-exocompute-us-east-1.cluster_connection_command),2)
  tunnel_image_name = element(split("=", element(split(" ", module.polaris-aws-cloud-native-customer-managed-exocompute-us-east-1.cluster_connection_command),3)),1)
  tunnel_args = split(" ", element(split(" -- ", module.polaris-aws-cloud-native-customer-managed-exocompute-us-east-1.cluster_connection_command),1))
}

data "aws_caller_identity" "current" {}

data "aws_ecr_authorization_token" "token" {
  provider = aws.aws_pcr_account
}

module "polaris-aws-cloud-native" {
  source  = "rubrikinc/polaris-cloud-native/aws"

  rsc_credentials                     = var.rsc_credentials
  aws_account_name                    = var.aws_account_name
  aws_account_id                      = var.aws_account_id
  aws_profile                         = var.aws_profile
  aws_regions                         = var.aws_regions
  rsc_aws_delete_snapshots_on_destroy = false
  rsc_aws_features                    = [
                                          {
                                            name              = "CLOUD_NATIVE_PROTECTION",
                                            permission_groups = []
                                          },
                                          {
                                            name              = "RDS_PROTECTION",
                                            permission_groups = []
                                          },
                                          {
                                            name              = "CLOUD_NATIVE_S3_PROTECTION"
                                            permission_groups = []
                                          },
                                          {
                                            name              = "EXOCOMPUTE"
                                            permission_groups = []
                                          },
                                          {
                                            name = "CLOUD_NATIVE_ARCHIVAL",
                                            permission_groups = []
                                          }
                                        ]
}

module "polaris-aws-cloud-native-exocompute-networking" {
  source  = "rubrikinc/polaris-cloud-native-exocompute-networking/aws"

  aws_exocompute_subnet_public_cidr   = "172.21.0.0/24"
  aws_exocompute_subnet_1_cidr        = "172.21.1.0/24"
  aws_exocompute_subnet_2_cidr        = "172.21.2.0/24"
  aws_exocompute_vpc_cidr             = "172.21.0.0/16"
  aws_profile                         = var.aws_profile
  rsc_exocompute_region               = var.exocompute_region
}

module "polaris-aws-cloud-native-customer-managed-exocompute" {
  source  = "rubrikinc/polaris-cloud-native-customer-managed-exocompute/aws"

  aws_exocompute_public_access            = var.aws_exocompute_public_access
  aws_exocompute_public_access_admin_cidr = var.aws_exocompute_public_access_admin_cidr
  aws_eks_worker_node_role_arn            = module.polaris-aws-cloud-native.aws_eks_worker_node_role_arn
  aws_iam_cross_account_role_arn          = module.polaris-aws-cloud-native.aws_iam_cross_account_role_arn
  aws_profile                             = var.aws_profile
  aws_security_group_control-plane_id     = module.polaris-aws-cloud-native-exocompute-networking.aws_security_group_control-plane_id
  aws_security_group_worker-node_id       = module.polaris-aws-cloud-native-exocompute-networking.aws_security_group_worker-node_id
  cluster_master_role_arn                 = module.polaris-aws-cloud-native.cluster_master_role_arn
  rsc_aws_cnp_account_id                  = module.polaris-aws-cloud-native.rsc_aws_cnp_account_id
  rsc_credentials                         = var.rsc_credentials
  rsc_exocompute_region                   = var.exocompute_region
  rsc_exocompute_subnet_1_id              = module.polaris-aws-cloud-native-exocompute-networking.rsc_exocompute_subnet_1_id
  rsc_exocompute_subnet_2_id              = module.polaris-aws-cloud-native-exocompute-networking.rsc_exocompute_subnet_2_id
  worker_instance_profile                 = module.polaris-aws-cloud-native.worker_instance_profile
}

module "polaris-aws-cloud-native-archival-location" {
  source                             = "rubrikinc/polaris-cloud-native-archival-location/aws"
  rsc_archive_location_bucket_prefix  = "${var.rsc_bucket_prefix}"
  rsc_archive_location_name           = "${var.aws_account_name}-Terraform-created-archive-location"
  rsc_aws_cnp_account_id              = module.polaris-aws-cloud-native.rsc_aws_cnp_account_id
  rsc_credentials                     = var.rsc_credentials
}

# Wait for RSC to recognize EKS Cluster. Also waits for the EKS Cluster to be ready after creation.
resource "time_sleep" "wait_for_polaris_sync" {
  create_duration = "3600s"
}

# Populate the container registry from the RSC registry.
# Uses the pcr.py sample script from the Polaris SDK to populate the registry.
# Sample script location: https://github.com/rubrikinc/rubrik-polaris-sdk-for-python/tree/beta/sample/pcr-aws
resource "null_resource" "populate_container_registry" {
  provisioner "local-exec" {
    command = "python3 ../../rubrik-polaris-sdk-for-python/sample/pcr-aws/pcr.py --keyfile ${var.rsc_credentials} --pcrFqdn ${split("/",data.aws_ecr_authorization_token.token.proxy_endpoint)[2]} --profile ${var.aws_pcr_profile}"
  }
}

resource "polaris_aws_private_container_registry" "default" {
  account_id = module.polaris-aws-cloud-native.rsc_aws_cnp_account_id
  native_id  = data.aws_caller_identity.current.account_id
  url        = split("/",data.aws_ecr_authorization_token.token.proxy_endpoint)[2]
  depends_on = [time_sleep.wait_for_polaris_sync, null_resource.populate_container_registry]
}

resource "kubernetes_pod" "rsc_exocompute_tunnel_pod-us-east-1" {
  depends_on = [ polaris_aws_private_container_registry.default ]
  metadata {
    name = local.tunnel_container_name
  }

  spec {
    container {
      image = local.tunnel_image_name
      name  = local.tunnel_container_name

      args = local.tunnel_args
    }
  }
}

resource "kubernetes_pod" "rsc_exocompute_tunnel_pod-us-west-2" {
  depends_on = [ polaris_aws_private_container_registry.default ]
  metadata {
    name = local.tunnel_container_name
  }

  spec {
    container {
      image = local.tunnel_image_name
      name  = local.tunnel_container_name

      args = local.tunnel_args
    }
  }
}

output "aws_ecr_repository_fqdn" {
  value = split("/",data.aws_ecr_authorization_token.token.proxy_endpoint)[2]
}

output "aws_ecr_repository_url" {
  value = data.aws_ecr_authorization_token.token.proxy_endpoint
}

output "cluster_connection_auth" {
  value = "aws eks update-kubeconfig --region ${var.exocompute_region} --name ${module.polaris-aws-cloud-native-customer-managed-exocompute-us-east-1.cluster_name} --profile ${var.aws_profile}"
}

output "cluster_connection_command" {
  value = module.polaris-aws-cloud-native-customer-managed-exocompute-us-east-1.cluster_connection_command
}