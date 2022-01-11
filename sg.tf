resource "aws_security_group" "security-group" {
  name   = "gitlab-runner-SG"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = module.vt-globals.vt_ip_address_cidrs
  }
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = "true"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.service_tags
}

