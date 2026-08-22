variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Base project name used for resource tags"
  type        = string
  default     = "oficina-mecanica"
}

variable "environment" {
  description = "Environment name used for default tagging"
  type        = string
  default     = "prod-simulated"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.35"
}

variable "eks_cluster_role_name" {
  description = "Existing IAM role name used by EKS cluster"
  type        = string
  default     = "LabEksClusterRole"
}

variable "eks_node_role_name" {
  description = "Existing IAM role name used by EKS managed node group"
  type        = string
  default     = "LabEksNodeRole"
}

variable "node_instance_type" {
  description = "EKS managed node group instance type"
  type        = string
  default     = "t3.small"
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 1
}

variable "aws_base_state_bucket" {
  description = "S3 bucket name that stores aws-base Terraform state"
  type        = string
  default     = "bkt-oficina-mecanica"
}

variable "aws_base_state_key" {
  description = "S3 object key for infra-base Terraform state"
  type        = string
  default     = "infra/prod-simulated/infra-base/terraform.tfstate"
}

variable "aws_base_state_region" {
  description = "AWS region where aws-base Terraform state bucket is hosted"
  type        = string
  default     = "us-east-1"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for shared workloads"
  type        = string
  default     = "oficina"
}

variable "k8s_postgres_user" {
  description = "Postgres username for Kubernetes Secret"
  type        = string
  default     = "postgres"
}

variable "k8s_postgres_db" {
  description = "Postgres database name for Kubernetes Secret"
  type        = string
  default     = "techchallenge"
}

variable "k8s_postgres_password" {
  description = "Postgres password injected from CI secret for Kubernetes Secret"
  type        = string
  sensitive   = true
}

variable "k8s_postgres_image" {
  description = "Postgres container image"
  type        = string
  default     = "postgres:16-alpine"
}

variable "enable_metrics_server" {
  description = "Install metrics-server in the cluster"
  type        = bool
  default     = true
}

variable "metrics_server_chart_version" {
  description = "Optional metrics-server Helm chart version"
  type        = string
  default     = ""
}
