terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = var.region
}


locals {
  secrets_json = file("${path.module}/secrets.json")
  secrets = jsondecode(local.secrets_json)

  database_password = local.secrets["database_password"]
  github_oauth_token      = local.secrets["github_oauth_token"]
  github_webhooks_token   = local.secrets["github_webhooks_token"]

  container_environment = [
    {
      name  = "spring.datasource.url"
      value = "jdbc:mysql://${module.rds_instance.hostname}:${var.database_port}/${var.database_name}?user=${var.database_user}&password=${local.database_password}"
    },
    {
      name  = "server_port"
      value = var.container_port
    }
  ]

  environment_variables = [
    {
      name  = "DOCKER_REPO_NAME"
      value = module.ecr.repository_name
      type = "PLAINTEXT"
    },
    {
      name  = "CONTAINER_NAME"
      value = var.container_name
      type = "PLAINTEXT"
    }
  ]

  container_port_mappings = [
    {
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
    }
  ]
}

module "label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=master"
  namespace  = var.namespace
  name       = var.name
  stage      = var.stage
  delimiter  = var.delimiter
  attributes = var.attributes
  tags       = var.tags
}

module "vpc" {
  source     = "git::https://github.com/cloudposse/terraform-aws-vpc.git?ref=master"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  delimiter  = var.delimiter
  attributes = var.attributes
  cidr_block = var.vpc_cidr_block
  tags       = var.tags
  enable_default_security_group_with_custom_rules = false
}

module "subnets" {
  source               = "git::https://github.com/cloudposse/terraform-aws-dynamic-subnets.git?ref=master"
  availability_zones   = var.availability_zones
  namespace            = var.namespace
  stage                = var.stage
  name                 = var.name
  attributes           = var.attributes
  delimiter            = var.delimiter
  vpc_id               = module.vpc.vpc_id
  igw_id               = module.vpc.igw_id
  cidr_block           = module.vpc.vpc_cidr_block
  nat_gateway_enabled  = true
  nat_instance_enabled = false
  tags                 = var.tags
}

module "rds_instance" {
  source               = "git::https://github.com/cloudposse/terraform-aws-rds.git?ref=master"
  namespace            = var.namespace
  stage                = var.stage
  name                 = var.name
  database_name        = var.database_name
  database_user        = var.database_user
  database_password    = local.database_password
  database_port        = var.database_port
  multi_az             = var.db_multi_az
  storage_type         = var.db_storage_type
  allocated_storage    = var.db_allocated_storage
  storage_encrypted    = var.db_storage_encrypted
  engine               = var.db_engine
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  db_parameter_group   = var.db_parameter_group
  publicly_accessible  = var.db_publicly_accessible
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = module.subnets.private_subnet_ids
  security_group_ids   = [module.vpc.vpc_default_security_group_id]
  apply_immediately    = var.db_apply_immediately
}

resource "aws_ecs_cluster" "cluster" {
  name = module.label.id
  tags = module.label.tags
}

data "aws_iam_policy_document" "ecs_instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_instance_role" {
  name = "${module.label.id}-ecs"
  assume_role_policy = data.aws_iam_policy_document.ecs_instance_assume_role_policy.json
  tags = module.label.tags
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${module.label.id}-ecs"
  path = "/"
  role = aws_iam_role.ecs_instance_role.name
  tags = module.label.tags
}

data "aws_ami" "ecs_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }
}

resource "aws_security_group" "egress" {
  description = "Allow all outbound traffic"

  name = "${var.name}-outbound"
  vpc_id = module.vpc.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = module.label.tags
}

module "autoscale_group" {
  source               = "git::https://github.com/cloudposse/terraform-aws-ec2-autoscale-group?ref=master"

  namespace            = var.namespace
  stage                = var.stage
  name                 = var.name
  tags = module.label.tags

  image_id                      = data.aws_ami.ecs_ami.image_id
  instance_type                 = var.instance_type
  subnet_ids                    = module.subnets.public_subnet_ids
  health_check_type             = var.health_check_type
  min_size                      = var.min_size
  max_size                      = var.max_size
  wait_for_capacity_timeout     = var.wait_for_capacity_timeout
  associate_public_ip_address   = true
  user_data_base64              = base64encode(local.userdata)
  metadata_http_tokens_required = true
  security_group_ids            = [module.vpc.vpc_default_security_group_id, aws_security_group.egress.id]

  # Auto-scaling policies and CloudWatch metric alarms
  autoscaling_policies_enabled           = true
  cpu_utilization_high_threshold_percent = var.cpu_utilization_high_threshold_percent
  cpu_utilization_low_threshold_percent  = var.cpu_utilization_low_threshold_percent

  iam_instance_profile_name = aws_iam_instance_profile.ecs_instance_profile.name


  block_device_mappings = [
    {
      device_name  = "/dev/sdb"
      no_device    = null
      virtual_name = null
      ebs = {
        delete_on_termination = true
        encrypted             = false
        volume_size           = 30
        volume_type           = "gp3"
        iops                  = null
        kms_key_id            = null
        snapshot_id           = null
      }
    }
  ]
}

# https://www.terraform.io/docs/configuration/expressions.html#string-literals
locals {
  userdata = <<-USERDATA
    #!/bin/bash
    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${aws_ecs_cluster.cluster.name}
    ECS_CONTAINER_INSTANCE_PROPAGATE_TAGS_FROM=ec2_instance
    EOF
  USERDATA
}

resource "aws_security_group" "alb" {
  description = "Allow connection to ALB port"

  name = "${var.name}-alb"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port        = var.container_port
    to_port          = var.container_port
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = module.label.tags
}

module "alb" {
  source                                  = "git::https://github.com/cloudposse/terraform-aws-alb?ref=master"
  namespace                               = var.namespace
  stage                                   = var.stage
  name                                    = var.name
  vpc_id                                  = module.vpc.vpc_id
  security_group_ids                      = [module.vpc.vpc_default_security_group_id, aws_security_group.alb.id]
  subnet_ids                              = module.subnets.public_subnet_ids
  internal                                = false
  http_enabled                            = true
  access_logs_enabled                     = false
  cross_zone_load_balancing_enabled       = true
  http2_enabled                           = true
  target_group_port                       = var.container_port
  stickiness                              = {
    enabled = true
    cookie_duration = 60
  }
  target_group_name                       = var.name
  security_group_enabled                  = false
  http_port                               = var.container_port
  health_check_path = "/health"
}

module "ecr" {
  source = "git::https://github.com/cloudposse/terraform-aws-ecr?ref=master"

  namespace                               = var.namespace
  stage                                   = var.stage
  name                                    = var.name
}

module "container_definition" {
  source  = "git::https://github.com/cloudposse/terraform-aws-ecs-container-definition?ref=master"

  container_name               = var.container_name
  container_image              = module.ecr.repository_url
  container_memory             = var.container_memory
  container_memory_reservation = var.container_memory_reservation
  container_cpu                = var.container_cpu
  essential                    = var.container_essential
  readonly_root_filesystem     = var.container_readonly_root_filesystem
  environment                  = local.container_environment
  port_mappings                = local.container_port_mappings

  log_configuration = {
    logDriver = "awslogs"
    options = {
        "awslogs-group" = var.name
        "awslogs-region" = var.region
      }
  }
}

module "ecs_alb_service_task" {
  source                             = "git::https://github.com/cloudposse/terraform-aws-ecs-alb-service-task?ref=master"

  namespace                               = var.namespace
  stage                                   = var.stage
  name                                    = var.name

  alb_security_group                 = aws_security_group.alb.id
  container_definition_json          = module.container_definition.json_map_encoded_list
  ecs_cluster_arn                    = aws_ecs_cluster.cluster.arn
  launch_type                        = var.ecs_launch_type
  vpc_id                             = module.vpc.vpc_id
  security_group_ids                 = [module.vpc.vpc_default_security_group_id, module.rds_instance.security_group_id, aws_security_group.alb.id]
  subnet_ids                         = module.subnets.public_subnet_ids
  ignore_changes_task_definition     = var.ignore_changes_task_definition
  network_mode                       = var.network_mode
  assign_public_ip                   = var.assign_public_ip
  propagate_tags                     = var.propagate_tags
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_controller_type         = var.deployment_controller_type
  desired_count                      = var.desired_count
  task_memory                        = var.task_memory
  task_cpu                           = var.task_cpu
  container_port                     = var.container_port


  ecs_load_balancers                 = [
    {
      elb_name         = ""
      container_name   = var.container_name
      container_port   = var.container_port
      target_group_arn = module.alb.default_target_group_arn
    }
  ]
}

module "ecs_codepipeline" {
  source                  = "git::https://github.com/cloudposse/terraform-aws-ecs-codepipeline.git?ref=master"
  cache_type              = "NO_CACHE"
  namespace               = var.namespace
  stage                   = var.stage
  name                    = var.name
  region                  = var.region
  github_oauth_token      = local.github_oauth_token
  github_webhooks_token   = local.github_webhooks_token
  repo_owner              = var.repo_owner
  repo_name               = var.repo_name
  branch                  = var.branch
  build_image             = var.build_image
  build_compute_type      = var.build_compute_type
  build_timeout           = var.build_timeout
  poll_source_changes     = var.poll_source_changes
  privileged_mode         = var.privileged_mode
  image_repo_name         = var.image_repo_name
  image_tag               = var.image_tag
  webhook_enabled         = var.webhook_enabled
  s3_bucket_force_destroy = var.s3_bucket_force_destroy
  environment_variables   = local.environment_variables
  ecs_cluster_name        = aws_ecs_cluster.cluster.name
  service_name            = module.ecs_alb_service_task.service_name
}
