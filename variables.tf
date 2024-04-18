variable "aws_account_id" {
  type        = string
  description = "AWS account ID of the AWS account that will host Excompute."
}

variable "aws_account_name" {
  type        = string
  description = "AWS account name."  
}

variable "aws_pcr_account_id" {
  type        = string
  description = "AWS account ID of the AWS account that pulls images from the Rubrik ECR."
}
variable "aws_pcr_profile" {
  type        = string
  description = "AWS Profile for the AWS account used to pull images from the Rubrik ECR"
}

variable "aws_profile" {
  type        = string
  description = "AWS profile."  
}

variable "aws_exocompute_public_access" {
  type        = bool
  description = "Enable public access to the Exocompute cluster." 
  default     = true
}

variable "aws_exocompute_public_access_admin_cidr" {
  type        = list(string)
  description = "CIDR block for the admin's public IP address."
  default     = []
}

variable "aws_regions" {
  type        = list(string)
  description = "AWS regions."  
}

variable "aws_security_group_control-plane_id" {
  type        = string
  description = "Security group ID for the EKS control plane."
}

variable "aws_security_group_worker-node_id" {
  type        = string
  description = "Security group ID for the EKS worker nodes."
}

variable "exocompute_region" {
  type        = string
  description = "AWS region for the Exocompute cluster."  
}

variable "rsc_bucket_prefix" {
  type        = string
  description = "Prefix for the Rubrik Security Cloud bucket."  
}

variable "rsc_credentials" {
  type        = string
  description = "Path to the Rubrik Security Cloud service account file."
}

variable "rsc_exocompute_subnet_1_id" {
  type        = string
  description = "Subnet 1 ID for the AWS account hosting Exocompute."  
}

variable "rsc_exocompute_subnet_2_id" {
  type        = string
  description = "Subnet 2 ID for the AWS account hosting Exocompute."  
}
