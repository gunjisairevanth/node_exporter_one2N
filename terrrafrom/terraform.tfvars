account_id                = "350931055052"
region                    = "ap-south-1"
vpc_cidr_block            = "11.0.0.0/16"
subnet1_cidr_block        = "11.0.1.0/24"
subnet2_cidr_block        = "11.0.2.0/24"
subnet3_cidr_block        = "11.0.3.0/24"
subnet1_availability_zone = "ap-south-1a"
subnet2_availability_zone = "ap-south-1b"
subnet3_availability_zone = "ap-south-1c"

###############################################

vpc_name                  = "ne_vpc"
private_subnet1_name      = "ne_vpc_private_subnet_a"
private_subnet2_name      = "ne_vpc_private_subnet_b"
public_subnet1_name       = "ne_vpc_public_subnet_a"

#################### EKS ###########################

cluster_name              = "ne_eks"
cluster_group_name        = "ne_nodepool"
cluster_job_group_name    = "ne_jobs"

#################### DNS ###########################

metrics_domain_name       = "metrics.staytools.com"
files_domain_name         = "files.staytools.com"
zone_id                   = "Z03354183NMVA3RU59GLJ"