# Define a variable for the prefix
variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
}

# Define an IAM policy document for assuming a role
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]  # Allow EKS service to assume this role
    }

    actions = ["sts:AssumeRole"]  # Action allowed by this policy
  }
}

# Create an IAM role for EKS cluster
resource "aws_iam_role" "example" {
  name               = "${var.prefix}_eks-cluster-cloud"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json  # Use the assume role policy defined above
}

# Attach the Amazon EKS Cluster Policy to the IAM role
resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"  # ARN of the policy to attach
  role       = aws_iam_role.example.name  # Role to attach this policy to
}

# Define a variable for the VPC ID where the EKS cluster will be created
variable "vpc_id" {
  description = "The ID of the VPC where the EKS cluster will be created"
  type        = string  # Type of the variable
}

# Fetch the VPC information using the VPC ID provided as input
data "aws_vpc" "selected" {
  id = var.vpc_id  # Use the VPC ID from the variable
}

# Fetch public subnets within the specified VPC
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"  # Filter by VPC ID
    values = [data.aws_vpc.selected.id]
  }

  # Filter to select only public subnets based on a tag
  filter {
    name   = "tag:Name"  # Tag name to filter public subnets
    values = ["*public*"]  # Assumes public subnets are tagged with 'public' in their Name tag
  }
}

# Create the EKS cluster
resource "aws_eks_cluster" "example" {
  name     = "${var.prefix}_EKS_CLOUD"
  role_arn = aws_iam_role.example.arn  # Role ARN for the EKS cluster to assume

  vpc_config {
    subnet_ids = data.aws_subnets.public.ids  # Use public subnets for the cluster
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
  ]
}

# Create an IAM role for EKS node group
resource "aws_iam_role" "example1" {
  name = "${var.prefix}_eks-node-group-cloud"

  # Define the assume role policy inline
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"  # Allow sts:AssumeRole action
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"  # Allow EC2 service to assume this role
      }
    }]
    Version = "2012-10-17"  # Policy version
  })
}

# Attach the Amazon EKS Worker Node Policy to the IAM role
resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"  # ARN of the policy to attach
  role       = aws_iam_role.example1.name  # Role to attach this policy to
}

# Attach the Amazon EKS CNI Policy to the IAM role
resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"  # ARN of the policy to attach
  role       = aws_iam_role.example1.name  # Role to attach this policy to
}

# Attach the Amazon EC2 Container Registry ReadOnly Policy to the IAM role
resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"  # ARN of the policy to attach
  role       = aws_iam_role.example1.name  # Role to attach this policy to
}

# Create the EKS node group
resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.example.name  # Name of the EKS cluster
  node_group_name = "${var.prefix}_Node-cloud"  # Name of the node group
  node_role_arn   = aws_iam_role.example1.arn  # ARN of the IAM role for the node group
  subnet_ids      = data.aws_subnets.public.ids  # Use the public subnets for the node group

  scaling_config {
    desired_size = 1  # Desired number of nodes
    max_size     = 2  # Maximum number of nodes
    min_size     = 1  # Minimum number of nodes
  }
  instance_types = ["t2.medium"]  # Instance type for the nodes

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.example-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.example-AmazonEC2ContainerRegistryReadOnly,
  ]
}
