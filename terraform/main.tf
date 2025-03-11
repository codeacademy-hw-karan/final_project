terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.38"
    }
  }
  required_version = ">= 1.2.0"

  backend "s3" { # Store Terraform state remotely
    bucket         = "tfstate-bucket-final"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "tfstate-lock-final"
  }
}

# 🔹 Define AWS Provider
provider "aws" {
  region = "eu-central-1"
}

# 🔹 Create VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# 🔹 Create Subnet
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
}

# 🔹 Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# 🔹 Route Table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.main.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# 🔹 Security Group (SSH, HTTP, App Port)
resource "aws_security_group" "instance_sg" {
  name        = "instance-sg"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.main.id

  ingress { # SSH Access
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # HTTP Access
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # Custom App Port (e.g., Node.js, Flask)
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { # Allow all outgoing traffic
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 🔹 Create EC2 Instance
resource "aws_instance" "main-vm" {
  ami                    = "ami-0d118c6e63bcb554e" # Ubuntu 22.04 AMI
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  key_name               = "your-key-name"  # Change this to your actual key pair name

  tags = {
    Name = "VM-CICD"
  }
}

# 🔹 Output Public IP for SSH & CI/CD
output "instance_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.main-vm.public_ip
}
