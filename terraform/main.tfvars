region = "eu-west-1"

availability_zones = ["eu-west-1a", "eu-west-1b"]

namespace = "smaliarov"

stage = "test"

name = "nordcloud"

vpc_cidr_block = "10.0.0.0/16"

ecs_launch_type = "EC2"

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

container_name = "nordcloud"

container_memory = 512

container_memory_reservation = 256

container_cpu = 256

container_essential = true

container_readonly_root_filesystem = false

container_port = 8080

repo_owner = "smaliarov"

repo_name = "nordcloud"

branch = "master"

build_image = "aws/codebuild/standard:5.0-21.04.23"

build_compute_type = "BUILD_GENERAL1_SMALL"

build_timeout = 60

poll_source_changes = true

privileged_mode = true

image_repo_name = "terraform-aws-ecs-codepipeline"

image_tag = "latest"

webhook_enabled = false

s3_bucket_force_destroy = true

db_deletion_protection = false

database_name = "notejam"

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

health_check_type = "EC2"

wait_for_capacity_timeout = "5m"

max_size = 2

min_size = 1

instance_type = "t3.micro"

cpu_utilization_high_threshold_percent = 80

cpu_utilization_low_threshold_percent = 40