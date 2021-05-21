region = "eu-west-1"

availability_zones = ["eu-west-1a", "eu-west-1b"]

namespace = "nordcloud"

stage = "test"

name = "ecs-codepipeline"

vpc_cidr_block = "10.0.0.0/16"

ecs_launch_type = "FARGATE"

network_mode = "awsvpc"

ignore_changes_task_definition = true

assign_public_ip = false

propagate_tags = "TASK_DEFINITION"

deployment_minimum_healthy_percent = 100

deployment_maximum_percent = 200

deployment_controller_type = "ECS"

desired_count = 1

task_memory = 512

task_cpu = 256

container_name = "geodesic"

container_image = "cloudposse/geodesic"

container_memory = 256

container_memory_reservation = 128

container_cpu = 256

container_essential = true

container_readonly_root_filesystem = false

container_port_mappings = [
  {
    containerPort = 8080
    hostPort      = 8080
    protocol      = "tcp"
  }
]

repo_owner = "smaliarov"

repo_name = "nordcloud"

branch = "master"

build_image = "aws/codebuild/docker:17.09.0"

build_compute_type = "BUILD_GENERAL1_SMALL"

build_timeout = 60

poll_source_changes = true

privileged_mode = true

image_repo_name = "terraform-aws-ecs-codepipeline"

image_tag = "latest"

webhook_enabled = false

s3_bucket_force_destroy = true

environment_variables = [
]

db_deletion_protection = false

database_name = "test_db"

database_user = "admin"

database_port = 3306

db_multi_az = false

db_storage_type = "standard"

db_storage_encrypted = false

db_allocated_storage = 5

db_engine = "mysql"

db_engine_version = "5.7.33"

db_major_engine_version = "5.7"

db_instance_class = "db.t2.micro"

db_parameter_group = "mysql5.7"

db_publicly_accessible = false

db_apply_immediately = true

db_availability_zone = "subnet_ids"
