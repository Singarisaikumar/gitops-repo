provider "aws" {
  region = "us-east-1"
}

# 1. Automatically discover an existing VPC network in your account
data "aws_vpc" "existing" {
  default = false
}

# 2. Automatically discover a subnet inside that existing network
data "aws_subnets" "existing_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

# 3. Create your network firewall doors inside the discovered existing network
resource "aws_security_group" "cloud_sg" {
  name        = "devops-automated-sg-v3"
  description = "Security rules for pure automation pipeline"
  vpc_id      = data.aws_vpc.existing.id # Reuses your existing network

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30808
    to_port     = 30808
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

# 4. Provision your cloud server inside the discovered existing subnet zone
resource "aws_instance" "cloud_server" {
  ami                    = "ami-04b70fa74e45c3917" # Ubuntu 24.04 LTS OS image
  instance_type          = "t3.medium"            # 2 vCPU, 4GB Memory
  subnet_id              = data.aws_subnets.existing_subnets.ids[0] # Automatically picks first subnet
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
