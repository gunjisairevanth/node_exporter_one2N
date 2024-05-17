variable "account_id" {}
variable "region" {}
variable "vpc_cidr_block" {}
variable "subnet1_cidr_block" {}
variable "subnet2_cidr_block" {}
variable "subnet3_cidr_block" {}
variable "subnet1_availability_zone" {}
variable "subnet2_availability_zone" {}
variable "subnet3_availability_zone" {}

####################################################

variable "vpc_name" {}
variable "private_subnet1_name" {}
variable "private_subnet2_name" {}
variable "public_subnet1_name" {}

#################### EKS ###########################

variable "cluster_name" {}
variable "cluster_group_name" {}
variable "cluster_job_group_name" {}


#################### DNS ###########################

variable "metrics_domain_name" {}
variable "zone_id" {}