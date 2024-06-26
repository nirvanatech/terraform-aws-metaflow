variable "db_instance_type" {
  type        = string
  description = "RDS instance type to launch for PostgresQL database."
  default     = "db.t2.small"
}

variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_engine_version" {
  type    = string
  default = "11"
}

variable "db_parameter_group_family" {
  type    = string
  default = "postgres11"
}

variable "db_name" {
  type        = string
  description = "Name of PostgresQL database for Metaflow service."
  default     = "metaflow"
}

variable "force_destroy_s3_bucket" {
  type        = bool
  description = "Empty S3 bucket before destroying via terraform destroy"
  default     = false
}
variable "db_username" {
  type        = string
  description = "PostgresQL username; defaults to 'metaflow'"
  default     = "metaflow"
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

variable "randomize_s3_name" {
  type        = bool
  default     = false
  description = "If set to true, adds a 8-character random alphanumeric suffix to s3 bucket name to make it globally unique"
}

variable "standard_tags" {
  type        = map(string)
  description = "The standard tags to apply to every AWS resource."
}

variable "subnet1_id" {
  type        = string
  description = "First subnet used for availability zone redundancy"
}

variable "subnet2_id" {
  type        = string
  description = "Second subnet used for availability zone redundancy"
}

variable "enable_s3_intelligent_tiering" {
  type        = bool
  description = "Choose to enable intelligent tiering on s3 bucket for reduced costs"
  default     = false
}

variable "db_multi_az" {
  type        = bool
  description = "Choose whether to enable multi-az deployments for increased fault tolerance of database"
  default     = true
}
