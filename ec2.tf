
module "gitlab-runner" {
  source                   = "git@code.vt.edu:devcom/terraform-modules/aws-gitlab-runner.git"
  environment              = "all"
  gitlab_runner_cache_name = "gitlab-runner-cache"
  gitlab_token             = "wJJ1cvcHg_6_eY1EptJd"
  tag_list                 = "docker,deploy,websitev2,runner,aws,repo.cw"
  responsible_party        = "sally"
  runner_name              = "gitlab-runner"
  ssh_key_name             = "contentwatch-dev"
  subnet_ids               = ["subnet-5170c50c", "subnet-028c395f"]
  vcs                      = "git@code.vt.edu:path/to/my/repo"
  vpc_id                   = "vpc-800e4cf8"
}


resource "aws_launch_template" "template" {
  name_prefix   = "${local.service_tags.Name}-"
  image_id      = data.aws_ami.ami.image_id
  instance_type = var.supervisor_instance_type
  key_name      = var.ssh_key_name
  user_data     = base64encode(data.template_file.gitlab_config.rendered)

  iam_instance_profile {
    arn = aws_iam_instance_profile.profile.arn
  }

  network_interfaces {
    security_groups       = [aws_security_group.security-group.id]
    delete_on_termination = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = local.service_tags
  }
}

resource "aws_autoscaling_group" "asg" {
  name                 = local.service_tags.Name
  max_size             = 1
  min_size             = 1
  desired_capacity     = 1
  force_delete         = true
  vpc_zone_identifier  = var.subnet_ids
  termination_policies = ["OldestInstance"]

  launch_template {
    id      = aws_launch_template.template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = local.service_tags.Name
    propagate_at_launch = "true"
  }

  tag {
    key                 = "Environment"
    value               = local.service_tags.Environment
    propagate_at_launch = "true"
  }

  tag {
    key                 = "ResponsibleParty"
    value               = local.service_tags.ResponsibleParty
    propagate_at_launch = "true"
  }

  tag {
    key                 = "DataRisk"
    value               = local.service_tags.DataRisk
    propagate_at_launch = "true"
  }

  tag {
    key                 = "ComplianceRisk"
    value               = local.service_tags.ComplianceRisk
    propagate_at_launch = "true"
  }

  tag {
    key                 = "Comments"
    value               = local.service_tags.Comments
    propagate_at_launch = "true"
  }

  tag {
    key                 = "VCS"
    value               = local.service_tags.VCS
    propagate_at_launch = "true"
  }
}

