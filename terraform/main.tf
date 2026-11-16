terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_security_group" "flaskapp" {
  name        = "flaskapp-tf"
  description = "SSH and Flask from my IP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["104.50.146.52/32"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["104.50.146.52/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "flaskapp" {
  ami                    = "ami-0e1011556f696c3d3"
  instance_type          = "t3.micro"
  key_name               = "1stAWSpair"
  vpc_security_group_ids = [aws_security_group.flaskapp.id]
  user_data              = file("../flaskapp/user-data.sh")

  tags = {
    Name = "flaskapp-tf"
  }
}

output "public_ip" {
  value = aws_instance.flaskapp.public_ip
}