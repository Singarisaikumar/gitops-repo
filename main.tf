provider "aws" {
  region = "us-east-1"
}

# 1. Automatically build a brand-new network from scratch
resource "aws_vpc" "custom_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "devops-automation-vpc" }
}

# 2. Automatically create an Internet Gateway to hook your network to the web
resource "aws_internet_gateway" "custom_igw" {
  vpc_id = aws_vpc.custom_vpc.id
  tags   = { Name = "devops-automation-igw" }
}

# 3. Automatically create a public subnet zone explicitly inside us-east-1a
resource "aws_subnet" "custom_subnet" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "devops-automation-subnet" }
}

# 4. Explicitly bind the open public internet route destination to the table
resource "aws_route_table" "custom_rt" {
  vpc_id = aws_vpc.custom_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.custom_igw.id
  }
  tags = { Name = "devops-automation-rt" }
}

# 5. Connect the public route table directly to your server's subnet zone
resource "aws_route_table_association" "custom_rta" {
  subnet_id      = aws_subnet.custom_subnet.id
  route_table_id = aws_route_table.custom_rt.id
}

# 6. Automatically create your network firewall doors using valid K8s port ranges
resource "aws_security_group" "cloud_sg" {
  name        = "devops-automated-sg"
  description = "Security rules for pure automation pipeline"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Open valid K8s port 30808 for your Argo CD Web Dashboard view
  ingress {
    from_port   = 30808
    to_port     = 30808
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Open valid K8s port 30080 for your live Node.js web application page view
  ingress {
    from_port   = 30080
    to_port     = 30080
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

# 7. Provision your cloud server inside your public zone
resource "aws_instance" "cloud_server" {
  ami                    = "ami-04b70fa74e45c3917" # Ubuntu 24.04 LTS OS image
  instance_type          = "t3.medium"            # 2 vCPU, 4GB Memory
  subnet_id              = aws_subnet.custom_subnet.id
  vpc_security_group_ids = [aws_security_group.cloud_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              
              # Install Lightweight Kubernetes (K3s) completely silent
              curl -sfL https://k3s.io | sh -
              export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
              chmod 644 /etc/rancher/k3s/k3s.yaml

              # Create tracking project workspaces
              /usr/local/bin/kubectl create namespace argocd
              /usr/local/bin/kubectl create namespace webapp

              # Deploy Core Argo CD engine directly from global repositories
              /usr/local/bin/kubectl apply -n argocd -f https://githubusercontent.com

              # Route traffic out safely using the valid K8s NodePort 30808
              /usr/local/bin/kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
              /usr/local/bin/kubectl patch svc argocd-server -n argocd --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/nodePort", "value": 30808}]'
              EOF

  tags = {
    Name = "Automated-DevOps-Server"
  }
}

output "your_public_cloud_ip" {
  value = aws_instance.cloud_server.public_ip
}
