variable "access_list_cidr_blocks" {
  type        = list(string)
  description = "List of CIDRs we want to grant access to our Metaflow Metadata Service. Usually this is our VPN's CIDR blocks."
}

variable "api_basic_auth" {
  type        = bool
  default     = true
  description = "Enable basic auth for API Gateway? (requires key export)"
}

variable "database_name" {
  type        = string
  default     = "metaflow"
  description = "The database name"
}

variable "database_password" {
  type        = string
  description = "The database password"
}

variable "database_username" {
  type        = string
  description = "The database username"
}

variable "database_sg_id" {
  type        = string
  description = "We will use this to add a ingress rule to RDS sg to allow metadata service access"
}

variable "database_aio_pool_max" {
  type        = number
  description = "Maximum active DB connections allowed to be held by the metadata service to the database"
  default     = 10
}

variable "database_aio_timeout" {
  type        = number
  description = "Timeout for database API calls from the metadata service"
  default     = 60
}

variable "datastore_s3_bucket_kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key used to encrypt the Metaflow datastore S3 bucket"
}

variable "fargate_execution_role_arn" {
  type        = string
  description = "The IAM role that grants access to ECS and Batch services which we'll use as our Metadata Service API's execution_role for our Fargate instance"
}

variable "iam_partition" {
  type        = string
  default     = "aws"
  description = "IAM Partition (Select aws-us-gov for AWS GovCloud, otherwise leave as is)"
}

variable "is_gov" {
  type        = bool
  default     = false
  description = "Set to true if IAM partition is 'aws-us-gov'"
}

variable "metadata_service_container_image" {
  type        = string
  default     = ""
  description = "Container image for metadata service"
}

variable "metadata_service_cpu" {
  type        = number
  default     = 512
  description = "ECS task CPU unit for metadata service"
}

variable "metadata_service_memory" {
  type        = number
  default     = 1024
  description = "ECS task memory in MiB for metadata service"
}

variable "metaflow_vpc_id" {
  type        = string
  description = "ID of the Metaflow VPC this SageMaker notebook instance is to be deployed in"
}

variable "resource_prefix" {
  type        = string
  description = "Prefix given to all AWS resources to differentiate between applications"
}

variable "resource_suffix" {
  type        = string
  description = "Suffix given to all AWS resources to differentiate between environment and workspace"
}

variable "rds_master_instance_endpoint" {
  type        = string
  description = "The database connection endpoint in address:port format"
}

variable "s3_bucket_arn" {
  type        = string
  description = "The ARN of the bucket we'll be using as blob storage"
}

variable "standard_tags" {
  type        = map(string)
  description = "The standard tags to apply to every AWS resource."
}

variable "subnet1_id" {
  type        = string
  description = "First private subnet used for availability zone redundancy"
}

variable "subnet2_id" {
  type        = string
  description = "Second private subnet used for availability zone redundancy"
}

variable "vpc_cidr_blocks" {
  type        = list(string)
  description = "The VPC CIDR blocks that we'll access list on our Metadata Service API to allow all internal communications"
}

variable "with_public_ip" {
  type        = bool
  default     = false
  description = "Enable private IP by default"
}
