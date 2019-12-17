#########################
# ECS Task Definition
#########################
resource "aws_iam_role" "task_execution" {
  name = "${var.name}-TaskExecution"

  assume_role_policy = <<EOL
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOL
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role = aws_iam_role.task_execution.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# MEMO:
#  タスク起動時にParameterStoreからDB接続情報やAPIキーを格納し、取得するためのRole
#  現状だと全件取得できてしまうため、実運用時には取得可能なパラメータを絞ることがベター
resource "aws_iam_role_policy" "task_execution" {
  role = aws_iam_role.task_execution.id

  policy = <<EOL
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters",
        "secretsmanager:GetSecretValue",
        "kms:Decrypt"
      ],
      "Resource": [
        "arn:aws:ssm:ap-northeast-1:${var.account_id}:parameter/*",
        "arn:aws:secretsmanager:ap-northeast-1:${var.account_id}:secret:*",
        "arn:aws:kms:ap-northeast-1:${var.account_id}:key/*"
      ]
    }
  ]
}
EOL
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/${var.name}/ecs"
  retention_in_days = "365"
}

resource "aws_ecs_task_definition" "this" {
  family = var.name
  tags   = var.tags

  container_definitions = var.container_definitions
  execution_role_arn    = aws_iam_role.task_execution.arn

  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
}

#########################
# ECS Service
#########################
resource "aws_lb_target_group" "this" {
  name = var.name
  tags = var.tags

  vpc_id = var.vpc_id

  port        = var.port
  protocol    = "HTTP"
  target_type = "ip"

  health_check {
    port    = var.port
    path    = "/"
    matcher = "200-399"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_alb_listener_rule" "this" {
  listener_arn = var.alb_https_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.id
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_ecs_service" "this" {
  name = var.name
  # MEMO: "InvalidParameterException: The new ARN and resource ID format must be enabled to add tags to the service. Opt in to the new format and try again." と出る場合はECSのAccountSettingが古いバージョンのままになっているのでアップデートしてください。
  tags = var.tags

  cluster         = var.ecs_cluster_name
  task_definition = aws_ecs_task_definition.this.arn

  launch_type   = "FARGATE"
  desired_count = var.service_desired_count

  network_configuration {
    subnets         = var.subnets
    security_groups = var.security_groups
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "main"
    container_port   = var.port
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}
