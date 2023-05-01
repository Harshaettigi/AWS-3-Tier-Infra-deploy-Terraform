provider "aws" {
  region = "us-east-2"
}

variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr_block_web" {
  default = "10.0.1.0/24"
}

variable "public_subnet_cidr_block_web_1" {
  default = "10.0.2.0/24"
}

variable "private_subnet_cidr_block_app" {
  default = "10.0.4.0/24"
}

variable "private_subnet_cidr_block_rds" {
  default = "10.0.5.0/24"
}
##############################################################
resource "aws_vpc" "Task" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "Task"
  }
}

resource "aws_subnet" "web" {
  vpc_id     = aws_vpc.Task.id
  cidr_block = var.public_subnet_cidr_block_web
  availability_zone = "us-east-2a"
  tags = {
    Name = "web"
  }
}

resource "aws_subnet" "web-1" {
  vpc_id     = aws_vpc.Task.id
  cidr_block = var.public_subnet_cidr_block_web_1
  availability_zone = "us-east-2b"
  tags = {
    Name = "web"
  }
}

resource "aws_subnet" "app" {
  vpc_id     = aws_vpc.Task.id
  cidr_block = var.private_subnet_cidr_block_app
  tags = {
    Name = "app"
  }
}

resource "aws_subnet" "rds" {
  vpc_id     = aws_vpc.Task.id
  cidr_block = var.private_subnet_cidr_block_rds
  tags = {
    Name = "rds"
  }
}


resource "aws_route_table" "web" {
  vpc_id = aws_vpc.Task.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-1.id
  }

  tags = {
    Name = "web"
  }
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.Task.id

  tags = {
    Name = "app"
  }
}

resource "aws_route_table" "rds" {
  vpc_id = aws_vpc.Task.id

  tags = {
    Name = "rds"
  }
}

resource "aws_route_table_association" "web" {
  subnet_id      = aws_subnet.web.id
  route_table_id = aws_route_table.web.id
}

resource "aws_route_table_association" "web-1" {
  subnet_id      = aws_subnet.web-1.id
  route_table_id = aws_route_table.web.id
}

resource "aws_route_table_association" "app" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table_association" "rds" {
  subnet_id      = aws_subnet.rds.id
  route_table_id = aws_route_table.rds.id
}

# Create internet gateway
resource "aws_internet_gateway" "igw-1" {
  vpc_id = aws_vpc.Task.id

  tags = {
    Name = "igw-1"
  }
}

resource "aws_nat_gateway" "nat-1" {
  allocation_id = aws_eip.nat-1.id
  subnet_id     = aws_subnet.web.id

  tags = {
    Name = "nat-1"
  }
}

resource "aws_eip" "nat-1" {
  vpc = true

  tags = {
    Name = "nat-1"
  }
}

resource "aws_instance" "bastion" {
  ami                    = "ami-06d5c50c30a35fb88"
  instance_type          = "t2.micro"
  #vpc_id            = aws_vpc.Task.id
  subnet_id              = aws_subnet.web.id
  vpc_security_group_ids = [aws_security_group.bastion-sg.id]

  tags = {
    Name = "bastion"
  }
}

resource "aws_instance" "app1" {
  ami           = "ami-06d5c50c30a35fb88"
  instance_type = "t2.micro"
  #vpc_id            = aws_vpc.Task.id
  subnet_id     = aws_subnet.app.id
  vpc_security_group_ids = [
    aws_security_group.ec2-app-sg.id
  ]

  tags = {
    Name = "app1"
  }
}

resource "aws_instance" "app2" {
  ami           = "ami-06d5c50c30a35fb88"
  instance_type = "t2.micro"
  #vpc_id            = aws_vpc.Task.id
  subnet_id     = aws_subnet.app.id
  vpc_security_group_ids = [
    aws_security_group.ec2-app-sg.id
  ]

  tags = {
    Name = "app2"
  }
}

resource "aws_security_group" "bastion-sg" {
  name_prefix = "bastion-sg"
  vpc_id      = aws_vpc.Task.id

  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_security_group" "ec2-app-sg" {
  name_prefix = "ec2-app-sg"
  vpc_id      = aws_vpc.Task.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-sg.id]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds-sg" {
  name_prefix = "rds-sg"
  vpc_id      = aws_vpc.Task.id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2-app-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "mydb_subnet_group" {
  name       = "mydb_subnet_group"
  subnet_ids = [aws_subnet.rds.id,aws_subnet.app.id]
}

resource "aws_db_instance" "rds" {
  allocated_storage = 20
  engine            = "mysql"
  engine_version    = "5.7"
  instance_class    = "db.t2.micro"
  db_name           = "mydb"
  username          = "admin"
  password          = "admin123"
  #vpc_id            = aws_vpc.Task.id
  #subnet_id         = aws_subnet.rds.id
  db_subnet_group_name  = aws_db_subnet_group.mydb_subnet_group.name
  vpc_security_group_ids = [
    aws_security_group.rds-sg.id
  ]

  tags = {
    Name = "rds"
  }
}

resource "aws_lb_target_group" "tg-app" {
  name_prefix = "tg-app"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.Task.id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    path                = "/health"
  }
}

resource "aws_lb" "alb" {
  name               = "web-lb"
  load_balancer_type = "application"
  #vpc_id            = aws_vpc.Task.id
  subnets            = [aws_subnet.web.id,aws_subnet.web-1.id]
  security_groups    = [aws_security_group.alb-sg.id]

  tags = {
    Name = "web-lb"
  }
}

resource "aws_security_group" "alb-sg" {
  name_prefix = "alb-sg"
  vpc_id      = aws_vpc.Task.id

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

resource "aws_lb_target_group_attachment" "tg-app-attachment" {
  target_group_arn = aws_lb_target_group.tg-app.arn
  target_id        = aws_instance.app1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "tg-app-attachment-2" {
  target_group_arn = aws_lb_target_group.tg-app.arn
  target_id        = aws_instance.app2.id
  port             = 80
}
