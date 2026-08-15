resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Allow inbound HTTP from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
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

  tags = {
    Name = "alb-sg"
  }
}


resource "aws_security_group" "app" {
  name        = "app-sg"
  description = "Allow inbound from ALB and inter-service traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Coupan port from ALB"
    from_port       = var.coupan_port
    to_port         = var.coupan_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Product port from ALB"
    from_port       = var.product_port
    to_port         = var.product_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Self-referencing: allow service-to-service traffic between tasks sharing this SG"
    from_port   = var.coupan_port
    to_port     = var.product_port
    protocol    = "tcp"
    self        = true
  }

    ingress {
    description = "Self-referencing: allow service-to-service traffic between tasks sharing this SG"
    from_port   = var.product_port
    to_port     = var.product_port
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-sg"
  }
}

resource "aws_security_group" "db" {
  name        = "db-sg"
  description = "Allow inbound MySQL from app tier only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from app tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-sg"
  }
}
