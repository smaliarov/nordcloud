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

  container_environment = [
    {
      name  = "db"
      value = module.rds_instance.instance_endpoint
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
  database_password    = local.secrets["database_password"]
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

resource "aws_ecs_cluster" "default" {
  name = module.label.id
  tags = module.label.tags
}

module "alb" {
  source                                  = "git::https://github.com/cloudposse/terraform-aws-alb?ref=master"
  namespace                               = var.namespace
  stage                                   = var.stage
  name                                    = var.name
  vpc_id                                  = module.vpc.vpc_id
  security_group_ids                      = [module.vpc.vpc_default_security_group_id]
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
  target_group_name = var.name
  security_group_enabled = false
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
}

module "ecs_alb_service_task" {
  source                             = "git::https://github.com/cloudposse/terraform-aws-ecs-alb-service-task?ref=master"

  namespace                               = var.namespace
  stage                                   = var.stage
  name                                    = var.name

  alb_security_group                 = module.vpc.vpc_default_security_group_id
  container_definition_json          = module.container_definition.json_map_encoded_list
  ecs_cluster_arn                    = aws_ecs_cluster.default.arn
  launch_type                        = var.ecs_launch_type
  vpc_id                             = module.vpc.vpc_id
  security_group_ids                 = [module.vpc.vpc_default_security_group_id]
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
  github_oauth_token      = local.secrets["github_oauth_token"]
  github_webhooks_token   = local.secrets["github_webhooks_token"]
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
  ecs_cluster_name        = aws_ecs_cluster.default.name
  service_name            = module.ecs_alb_service_task.service_name
}
