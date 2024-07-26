# prefix - this will be the prefix for every resource created - it will be same as the instance name
variable "resource_prefix" {
  description = "Prefix for all resource names."
  type        = string
  default     = "example-com"
}
# ami lookup vars
variable "ami_name_pattern" {
  description = "The pattern to search for AMI names."
  type        = string
  default     = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
}

variable "virtualization_type" {
  description = "The virtualization type of the AMI."
  type        = string
  default     = "hvm"
}

variable "ami_owners" {
  description = "The list of owner IDs to filter AMIs."
  type        = string
  default     = "099720109477"
}

# instance
variable "instance_type" {
  description = "The type of instance to start."
  type        = string
  default     = "t2.micro"
}

variable "disable_api_stop" {
  description = "Whether to disable API stop for the instance."
  type        = bool
  default     = true
}

variable "disable_api_termination" {
  description = "Whether to disable API termination for the instance."
  type        = bool
  default     = true
}

variable "monitoring" {
  description = "Whether to enable detailed monitoring."
  type        = bool
  default     = true
}

variable "root_block_device_volume_size" {
  description = "Size of the root block device volume in GiB."
  type        = number
  default     = 8
}

variable "root_block_device_volume_type" {
  description = "Type of the root block device volume (e.g., gp3, io1)."
  type        = string
  default     = "gp3"
}

variable "root_block_device_delete_on_termination" {
  description = "Whether the root block device should be deleted on termination."
  type        = bool
  default     = true
}

# key
variable "public_key" {
  description = "The public key material."
  type        = string
  default     = "ssh-ed25519 ..."
}

# s3
variable "s3_bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = "example"
}
