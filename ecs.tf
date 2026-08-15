resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

resource "aws_service_discovery_http_namespace" "main" {
  name = var.service_connect_namespace
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "ecs_execution" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"

      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_iam_policy" "ecs_exec_ssm" {
  name = "${var.project_name}-ecs-exec-ssm-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_exec_ssm.arn
}

resource "aws_cloudwatch_log_group" "coupan" {
  name              = "/ecs/${var.project_name}/coupan-app"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "product" {
  name              = "/ecs/${var.project_name}/product-app"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "coupan" {
  family                   = "coupan-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "coupan-app"
      image     = var.coupan_image
      essential = true
      portMappings = [
        {
          name          = "coupan-port"
          containerPort = var.coupan_port
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "MYSQL_HOST", value = aws_db_instance.main.address },
        { name = "MYSQL_USER", value = var.db_username },
        { name = "MYSQL_PASSWORD", value = var.db_password }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.coupan.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "coupan"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "coupan" {
  name                           = "coupan-service"
  cluster                        = aws_ecs_cluster.main.id
  task_definition                = aws_ecs_task_definition.coupan.arn
  desired_count                  = 2
  launch_type                    = "FARGATE"
  availability_zone_rebalancing  = "ENABLED"
  enable_execute_command          = true


  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn

    service {
      port_name      = "coupan-port"
      discovery_name = "coupan-service"

      client_alias {
        port = var.coupan_port
        dns_name = "${var.service_connect_namespace}.coupan-service"

      }
    }
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.coupan.arn
    container_name    = "coupan-app"
    container_port   = var.coupan_port
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_task_definition" "product" {
  family                   = "product-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "product-app"
      image     = var.product_image
      essential = true
      portMappings = [
        {
          name          = "product-port"
          containerPort = var.product_port
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "MYSQL_HOST", value = aws_db_instance.main.address },
        { name = "MYSQL_USER", value = var.db_username },
        { name = "MYSQL_PASSWORD", value = var.db_password },
        { name = "COUPAN_SERVICE_HOST", value = "${var.service_connect_namespace}.coupan-service" }
        # { name = "COUPAN_SERVICE_HOST", value = "coupan-service" }

      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.product.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "product"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "product" {
  name                           = "product-service"
  cluster                        = aws_ecs_cluster.main.id
  task_definition                = aws_ecs_task_definition.product.arn
  desired_count                  = 2
  launch_type                    = "FARGATE"
  availability_zone_rebalancing  = "ENABLED"
  enable_execute_command          = true

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn

    service {
      port_name      = "product-port"
      discovery_name = "product-service"

      client_alias {
        port = var.product_port
        dns_name = "${var.service_connect_namespace}.product-service"

      }
    }
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.product.arn
    container_name    = "product-app"
    container_port   = var.product_port
  }

  depends_on = [aws_lb_listener.http]
}
