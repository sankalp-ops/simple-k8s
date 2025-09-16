terraform {
  backend "s3" {
    bucket         = "myfibapp-tf-state-bucket"
    key            = "terraform.tfstate"
    region         = "us-east-1" # required here
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

output "aws_region" {
  value = "us-east-1"
}

resource "aws_iam_role" "eks_role" {
  name = "EKSClusterRole"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : [
              "eks.amazonaws.com"
            ]
          },
          "Action" : "sts:AssumeRole"
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "eks_policy" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_route53_zone" "myapps_dns" {
  name = "myfibapp.xyz"
}

output "aws_myapps_dns" {
  value = aws_route53_zone.myapps_dns.name
}

data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_subnets" "default_subnet" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"] # Replace with your target AZ
  }
}

resource "aws_eks_cluster" "k8s-cluster" {
  name     = "simple-k8s-cluster"
  role_arn = aws_iam_role.eks_role.arn
  vpc_config {
    subnet_ids = data.aws_subnets.default_subnet.ids
  }
  depends_on = [aws_iam_role_policy_attachment.eks_policy]
}

output "k8s-cluster" {
  value = aws_eks_cluster.k8s-cluster.name

}

# Rules for setting up a storage device within EKS

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.k8s-cluster.name
  addon_name               = "aws-ebs-csi-driver"
  depends_on               = [aws_eks_node_group.example]
  service_account_role_arn = aws_iam_role.csi_irsa_role.arn
}

resource "aws_iam_role" "iam_node_role" {
  name = "node-group-role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "sts:AssumeRole"
          ],
          "Principal" : {
            "Service" : [
              "ec2.amazonaws.com"
            ]
          }
        }
      ]
    }
  )
}

# To enable IMDSV2 resources "oidc" and "csi_irsa_role" are used.

resource "aws_iam_openid_connect_provider" "oidc" {
  url             = aws_eks_cluster.k8s-cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0ecd49f8a"] # AWS default
}

resource "aws_iam_role" "csi_irsa_role" {
  name = "csi_irsa_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.oidc.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            # OIDC issuer URL without https://
            "${replace(aws_eks_cluster.k8s-cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "external_dns_role" {
  name = "external_dns_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.oidc.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            # OIDC issuer URL without https://
            "${replace(aws_eks_cluster.k8s-cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:external-dns:external-dns"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.iam_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryPullOnly" {
  role       = aws_iam_role.iam_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.iam_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "AmazonEBSCSIDriverPolicy" {
  role = aws_iam_role.csi_irsa_role.name
  #role = aws_iam_role.iam_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "AmazonRoute53FullAccess" {
  role       = aws_iam_role.external_dns_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
}

resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.k8s-cluster.name
  node_group_name = "simple-k8s-cluster-nodes"
  node_role_arn   = aws_iam_role.iam_node_role.arn
  subnet_ids      = data.aws_subnets.default_subnet.ids

  scaling_config {
    desired_size = 3
    max_size     = 4
    min_size     = 2
  }

  instance_types = ["t2.small"]

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryPullOnly,
    aws_iam_role_policy_attachment.AmazonEBSCSIDriverPolicy
  ]

}
