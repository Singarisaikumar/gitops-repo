provider "aws" {
  region = "us-east-1"
}

# 1. This block automatically creates your network firewall doors
resource "aws_security_group" "cloud_sg" {
  name        = "devops-automated-sg"
  description = "Security rules for pure automation pipeline"

  # Open Port 22 for secure command line access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Open Port 8080 for your Argo CD Web Dashboard console view
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Open Port 30080 for your live Node.js web application page view
  ingress {
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Open outbound channel so the server can download secure packages
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. This block provisions your cloud server and installs all tools silently
resource "aws_instance" "cloud_server" {
  ami                    = "ami-04b70fa74e45c3917" # Official Ubuntu 24.04 LTS OS image
  instance_type          = "t3.medium"            # Server sizing size (2 vCPU, 4GB Memory)
  vpc_security_group_ids = [aws_security_group.cloud_sg.id]

  # This startup script executes completely by itself on boot up sequence
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

              # Route traffic out to your browser screen via port 8080 NodePort
              /usr/local/bin/kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
              /usr/local/bin/kubectl patch svc argocd-server -n argocd --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/nodePort", "value": 8080}]'
              EOF

  tags = {
    Name = "Automated-DevOps-Server"
  }
}

# Print out your live cloud website address path on terminal logs when completed
output "your_public_cloud_ip" {
  value = aws_instance.cloud_server.public_ip
}
