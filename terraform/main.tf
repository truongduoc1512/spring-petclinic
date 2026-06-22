# 1. Khai báo nhà cung cấp (Provider) là AWS
provider "aws" {
  region = "ap-southeast-2" # Chọn region Sydney (ap-southeast-2)
}

# 2. Tạo Mạng ảo (VPC) và Internet Gateway
resource "aws_vpc" "petclinic_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "petclinic-vpc" }
}

resource "aws_internet_gateway" "petclinic_igw" {
  vpc_id = aws_vpc.petclinic_vpc.id
  tags   = { Name = "petclinic-igw" }
}

# 3. Tạo Public Subnet & Route Table để server có thể ra vào Internet
resource "aws_subnet" "petclinic_public_subnet" {
  vpc_id                  = aws_vpc.petclinic_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true # Tự động cấp IP Public cho EC2
  tags                    = { Name = "petclinic-public-subnet" }
}

resource "aws_route_table" "petclinic_public_rt" {
  vpc_id = aws_vpc.petclinic_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.petclinic_igw.id
  }
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.petclinic_public_subnet.id
  route_table_id = aws_route_table.petclinic_public_rt.id
}

# 4. Tạo Security Group (Tường lửa)
resource "aws_security_group" "petclinic_sg" {
  name        = "petclinic-sg"
  description = "Allow SSH and App inbound traffic"
  vpc_id      = aws_vpc.petclinic_vpc.id

  # Mở port 22 để SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Thực tế nên giới hạn IP nhà bạn
  }

  # Mở port 8080 cho ứng dụng PetClinic
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Cho phép server tải các gói cài đặt từ Internet về
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "petclinic_deployer_key" {
  key_name   = "devops-petclinic-tf-key"
  public_key = file(pathexpand("~/.ssh/devops-petclinic-key.pub"))
}

# 5. Khởi tạo máy chủ EC2 (Ubuntu 22.04)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "petclinic_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro" # Nằm trong Free Tier (ap-southeast-2)
  subnet_id              = aws_subnet.petclinic_public_subnet.id
  vpc_security_group_ids = [aws_security_group.petclinic_sg.id]

  # LƯU Ý: Điền tên Key Pair bạn đã tạo trên AWS Console vào đây (không cần đuôi .pem)
  key_name = aws_key_pair.petclinic_deployer_key.key_name

  # Cấu hình ổ đĩa cứng (EBS Root Volume)
  root_block_device {
    volume_size = 20 # Tăng lên 20GB tránh bị đầy ổ cứng khi chạy Docker, Free Tier hỗ trợ tối đa 30GB
    volume_type = "gp3"
  }

  # Script chạy tự động lúc khởi động để cài Docker & Docker Compose
  user_data = <<-EOF
              #!/bin/bash
              # Cập nhật hệ thống
              apt-get update -y
              apt-get install -y curl

              # Cài đặt Docker bằng Script chính thức
              curl -fsSL https://get.docker.com | sh
              
              # Cấu hình quyền chạy Docker cho user ubuntu
              usermod -aG docker ubuntu

              # Khởi tạo symlink cho docker-compose (V2)
              ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
              EOF

  tags = { Name = "PetClinic-Production-Server" }
}

# Output: In ra IP Public của Server sau khi tạo xong
output "server_public_ip" {
  value = aws_instance.petclinic_server.public_ip
}

output "server_instance_id" {
  value = aws_instance.petclinic_server.id
}
