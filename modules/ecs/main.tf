# Step 1: Request a TLS certificate from ACM for the ALB domain.
# DNS validation is used — a CNAME record is created in Route 53 and
# Terraform waits until AWS confirms the certificate is issued.

resource "aws_acm_certificate" "main" {
  domain_name       = "*.${var.domain_name}"
  validation_method = "DNS"
  tags              = var.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Step 2: Create an ECR repository to store Docker images for both
# the frontend and backend services. Vulnerability scanning runs on every push.

resource "aws_ecr_repository" "main" {
  name = "app-repo"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.common_tags
}

# Step 3: Create the ECS cluster — the logical grouping that manages
# the frontend and backend Fargate services.

resource "aws_ecs_cluster" "main" {
  name = "ecs-cluster"
  tags = var.common_tags
}

# Step 4: Create the task execution IAM role so Fargate can pull images
# from ECR and send container logs to CloudWatch on behalf of the tasks.

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Step 5: Create the ECS service IAM role so the ECS control plane can
# register and deregister targets with the ALB on behalf of the services.

resource "aws_iam_role" "ecs_service" {
  name = "ecs-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_service" {
  role       = aws_iam_role.ecs_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

# Step 6: Create the public ALB security group — allows inbound HTTPS (443)
# from the internet and all outbound so the ALB can forward traffic to frontend.

resource "aws_security_group" "alb" {
  vpc_id      = var.vpc_id
  description = "Security group for public ALB"

  ingress {
    description = "HTTPS from internet"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "public-alb-sg" })
}

# Step 7a: Create the internal ALB security group and the ECS security group.
# Because they reference each other (ECS tasks → internal ALB, internal ALB →
# ECS tasks), the cross-referencing ingress rules are added as standalone
# aws_security_group_rule resources to avoid a circular dependency.

resource "aws_security_group" "internal_alb" {
  vpc_id      = var.vpc_id
  description = "Security group for internal ALB"

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "internal-alb-sg" })
}

resource "aws_security_group" "ecs" {
  vpc_id      = var.vpc_id
  description = "Security group for ECS tasks"

  ingress {
    description     = "Frontend traffic from public ALB"
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "ecs-sg" })
}

resource "aws_security_group_rule" "internal_alb_from_ecs" {
  type                     = "ingress"
  description              = "HTTP from frontend tasks"
  security_group_id        = aws_security_group.internal_alb.id
  source_security_group_id = aws_security_group.ecs.id
  protocol                 = "tcp"
  from_port                = 80
  to_port                  = 80
}

resource "aws_security_group_rule" "ecs_from_internal_alb" {
  type                     = "ingress"
  description              = "Backend traffic from internal ALB"
  security_group_id        = aws_security_group.ecs.id
  source_security_group_id = aws_security_group.internal_alb.id
  protocol                 = "tcp"
  from_port                = 3000
  to_port                  = 3000
}

# Step 8: Create the internet-facing Application Load Balancer in the public
# subnets. It accepts HTTPS traffic and forwards everything to the frontend.

resource "aws_lb" "main" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
  tags               = var.common_tags
}

# Step 8b: Create the internal Application Load Balancer in private subnets.
# The frontend service routes backend requests through this private ALB.

resource "aws_lb" "internal" {
  name               = "ecs-internal-alb"
  internal           = true
  load_balancer_type = "application"
  subnets            = var.private_subnet_ids
  security_groups    = [aws_security_group.internal_alb.id]
  tags               = var.common_tags
}

# Step 9: Create the frontend target group for the public ALB (port 80,
# health check /) and the backend target group for the internal ALB
# (port 3000, health check /api/health). Both use IP target type as
# required by Fargate's awsvpc networking mode.

resource "aws_lb_target_group" "frontend" {
  vpc_id      = var.vpc_id
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"

  health_check {
    path = "/"
  }

  tags = merge(var.common_tags, { Name = "frontend-tg" })
}

resource "aws_lb_target_group" "backend" {
  vpc_id      = var.vpc_id
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"

  health_check {
    path = "/api/health"
  }

  tags = merge(var.common_tags, { Name = "backend-tg" })
}

# Step 10: Create the HTTPS listener on the public ALB (port 443) that
# terminates TLS using the validated ACM certificate. All traffic goes
# to the frontend — there is no public route to the backend.

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Step 11: Create the HTTP listener on the internal ALB (port 80) that
# forwards all traffic to the backend target group.

resource "aws_lb_listener" "internal" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# Step 12: Create a public DNS A record (teja-demo.chakra86.store) that aliases
# to the ALB so the app is reachable via a friendly domain name.

resource "aws_route53_record" "app" {
  zone_id = var.hosted_zone_id
  name    = "teja-demo.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Step 13: Create a private DNS namespace (ecsworkshop.local) inside the VPC
# and register the backend service so the frontend can discover it at
# backend.ecsworkshop.local without going through the load balancer.

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "ecsworkshop.local"
  vpc         = var.vpc_id
  description = "Private DNS namespace for ECS service discovery"
  tags        = var.common_tags
}

resource "aws_service_discovery_service" "backend" {
  name = "backend"

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.main.id
    routing_policy = "MULTIVALUE"

    dns_records {
      type = "A"
      ttl  = 60
    }
  }
}

# Step 13: Create CloudWatch log groups for each service with a 7-day
# retention policy. Container logs are shipped here via the awslogs driver.

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/frontend"
  retention_in_days = 7
  tags              = var.common_tags
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/backend"
  retention_in_days = 7
  tags              = var.common_tags
}

# Step 14: Define the frontend task — runs on Fargate with 0.25 vCPU and
# 512 MB memory. Pulls the frontend-latest image from ECR and logs to CloudWatch.

data "aws_region" "current" {}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "frontend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name      = "frontend"
    image     = "${aws_ecr_repository.main.repository_url}:frontend-latest"
    essential = true
    portMappings = [{
      containerPort = 80
    }]
    environment = [{
      name  = "BACKEND_URL"
      value = "http://${aws_lb.internal.dns_name}"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "frontend"
      }
    }
  }])

  tags = var.common_tags
}

# Step 15: Define the backend task — same Fargate sizing as frontend.
# Pulls the backend-latest image from ECR and exposes port 3000.

resource "aws_ecs_task_definition" "backend" {
  family                   = "backend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name      = "backend"
    image     = "${aws_ecr_repository.main.repository_url}:backend-latest"
    essential = true
    portMappings = [{
      containerPort = 3000
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "backend"
      }
    }
  }])

  tags = var.common_tags
}

# Step 16: Create the frontend ECS service — runs on Fargate in private subnets
# behind the ALB. Desired count starts at 0 until container images are pushed to ECR.

resource "aws_ecs_service" "frontend" {
  name            = "frontend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 0
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    container_name   = "frontend"
    container_port   = 80
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  depends_on = [aws_lb_listener.https]

  tags = var.common_tags
}

# Step 17: Create the backend ECS service — runs on Fargate in private subnets
# behind the internal ALB. Also registers with Cloud Map for service discovery.

resource "aws_ecs_service" "backend" {
  name            = "backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 0
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    container_name   = "backend"
    container_port   = 3000
    target_group_arn = aws_lb_target_group.backend.arn
  }

  service_registries {
    registry_arn = aws_service_discovery_service.backend.arn
  }

  depends_on = [aws_lb_listener.internal]

  tags = var.common_tags
}

# Step 18: Register each service with Application Auto Scaling so the task count
# adjusts automatically between min_capacity and max_capacity.

resource "aws_appautoscaling_target" "frontend" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.frontend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
}

resource "aws_appautoscaling_target" "backend" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
}

# Step 19: Add CPU-based scaling policies — when average CPU utilization exceeds
# 80%, Auto Scaling adds tasks; when it drops, tasks are removed.

resource "aws_appautoscaling_policy" "frontend_cpu" {
  name               = "frontend-cpu-scaling"
  service_namespace  = aws_appautoscaling_target.frontend.service_namespace
  resource_id        = aws_appautoscaling_target.frontend.resource_id
  scalable_dimension = aws_appautoscaling_target.frontend.scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.scaling_cpu_threshold
  }
}

resource "aws_appautoscaling_policy" "backend_cpu" {
  name               = "backend-cpu-scaling"
  service_namespace  = aws_appautoscaling_target.backend.service_namespace
  resource_id        = aws_appautoscaling_target.backend.resource_id
  scalable_dimension = aws_appautoscaling_target.backend.scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.scaling_cpu_threshold
  }
}

# Step 20: Add memory-based scaling policies — triggers scaling when average
# memory exceeds the configured threshold.

resource "aws_appautoscaling_policy" "frontend_memory" {
  name               = "frontend-memory-scaling"
  service_namespace  = aws_appautoscaling_target.frontend.service_namespace
  resource_id        = aws_appautoscaling_target.frontend.resource_id
  scalable_dimension = aws_appautoscaling_target.frontend.scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = var.scaling_memory_threshold
  }
}

resource "aws_appautoscaling_policy" "backend_memory" {
  name               = "backend-memory-scaling"
  service_namespace  = aws_appautoscaling_target.backend.service_namespace
  resource_id        = aws_appautoscaling_target.backend.resource_id
  scalable_dimension = aws_appautoscaling_target.backend.scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = var.scaling_memory_threshold
  }
}
