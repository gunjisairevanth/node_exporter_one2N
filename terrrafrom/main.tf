resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = var.vpc_name
  }
}
########################### SUBNETS ###########################
resource "aws_subnet" "private_subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet1_cidr_block
  availability_zone = var.subnet1_availability_zone
  map_public_ip_on_launch = false
  tags = {
    Name = var.private_subnet1_name
  }
}

resource "aws_subnet" "private_subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet2_cidr_block
  availability_zone = var.subnet2_availability_zone
  map_public_ip_on_launch = false
  tags = {
    Name = var.private_subnet2_name
  }
}

resource "aws_subnet" "public_subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet3_cidr_block
  availability_zone = var.subnet3_availability_zone
  map_public_ip_on_launch = true
  tags = {
    Name = var.public_subnet1_name
  }
}

###################### Elastic Ip and NAT Creation ######################

resource "aws_eip" "lb" {
  domain   = "vpc"
}
resource "aws_nat_gateway" "example" {
  allocation_id = aws_eip.lb.id
  subnet_id     = aws_subnet.public_subnet1.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.example.id
}


resource "aws_route_table_association" "ne_private_nat_1" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "ne_private_nat_2" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private.id
}

######################## Internet Gatweway ########################


resource "aws_internet_gateway" "ne_internet_gateway" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "ne_internet_gateway" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "ne_internet_gateway" {
  route_table_id         = aws_route_table.ne_internet_gateway.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ne_internet_gateway.id
}

resource "aws_route_table_association" "ne_internet_gateway" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.ne_internet_gateway.id
}

######################### Roles for EKS ##################

# IAM role for the EKS cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks_cluster_role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "eks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}



# Attach the IAM policy to the IAM role for the EKS cluster
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# IAM role for the EKS node group
resource "aws_iam_role" "eks_node_role" {
  name = "eks_node_role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "ecr_read_only_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

################# Security Group ##################
resource "aws_security_group" "kubernetes" {
  name        = "kubernetes"
  description = "Security group for Kubernetes cluster"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################### EKS ###########################


provider "kubernetes" {
  host                   = aws_eks_cluster.my_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.my_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.my_cluster.token
}

data "aws_eks_cluster" "my_cluster" {
  name = aws_eks_cluster.my_cluster.name
}

data "aws_eks_cluster_auth" "my_cluster" {
  name = aws_eks_cluster.my_cluster.name
}


resource "aws_eks_cluster" "my_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version = "1.28"
  vpc_config {
    subnet_ids      = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id, aws_subnet.public_subnet1.id]  # Use your private subnets
  }
}


resource "aws_eks_node_group" "my_node_group" {
  cluster_name    = aws_eks_cluster.my_cluster.name
  node_group_name = var.cluster_group_name
  node_role_arn   = aws_iam_role.eks_node_role.arn

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }
  instance_types = ["t3.medium"] 
  subnet_ids      = [aws_subnet.public_subnet1.id]  # Use your private subnets
  depends_on = [aws_eks_cluster.my_cluster]

   remote_access {
    ec2_ssh_key = "node_exporter"
    source_security_group_ids = [aws_security_group.kubernetes.id]
  }

}


############################ EC2 Bastion Vm #######################

resource "aws_instance" "bastion" {
  ami           = "ami-0f58b397bc5c1f2e8"  # Canonical, Ubuntu, 24.04 LTS,
  instance_type = "t3.small"
  subnet_id     = aws_subnet.public_subnet1.id
  key_name      = "node_exporter"
  vpc_security_group_ids = [aws_security_group.kubernetes.id]
  tags = {
    Name = "bastion-ne"
  }
}


