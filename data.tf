# Get the AMI for our bastion
data "aws_ami" "ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_filter]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  owners = [var.ami_owner]
}

data "aws_vpc" "vpc" {
  filter {
    name = "tag:Name"
    values = ["dev-vpc"]
  }
}

data "aws_subnet_ids" "public" {
  vpc_id = var.vpc_id
  
  filter {
    name   = "tag:Name"
    values = ["dev-public-*"]
  }
}

data "template_file" "gitlab_config" {
  template = base64encode(file("user-data.sh."))
  vars = {
    log_group            = aws_cloudwatch_log_group.log_group.name
    token                = var.gitlab_token
    config_secret_id     = var.gitlab_config_secret_id
    cache_bucket         = aws_s3_bucket.cache.bucket
    region               = var.aws_region
    ami                  = data.aws_ami.ami.image_id
    vpc_id               = var.vpc_id
    subnet_id            = data.aws_subnet_ids.public.id
    subnet_az            = substr(data.aws_subnet.subnet.availability_zone, -1, 1)
    instance_type        = var.instance_type
    security_group       = aws_security_group.security-group.name
    runner_version       = var.gitlab_runner_version
    runner_name          = var.runner_name
    runner_tags          = var.runner_tags
    gitlab_url           = var.gitlab_url
    tags                 = "%{for tag, val in local.service_tags~} %{if tag != "Name"}${tag},${val},%{endif} %{endfor~}"
    iam_instance_profile = var.machine_iam_instance_profile
    idle_nodes           = var.machine_idle_nodes
    idle_time            = var.machine_idle_time
    max_builds           = var.machine_max_builds
    off_peak_timezone    = var.machine_off_peak_timezone
    off_peak_idle_nodes  = var.machine_off_peak_idle_nodes
    off_peak_idle_time   = var.machine_off_peak_idle_time
  }
}