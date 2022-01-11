###
# Required
###
variable "gitlab_runner_cache_name" {
  description = "S3 bucket name to be used for the gitlab runner cache"
  type        = string
  default     = "tf--s3-states"
}

variable "responsible_party" {
  description = "Person (pid) who is primarily responsible for the configuration and maintenance of this resource"
  type        = string
  default     = "admin"
}

variable "ssh_key_name" {
  description = "Name of the SSH key you want to use to access the bastion"
  type        = string
  default     = "contentwatch-dev"
}

variable "subnet_ids" {
  description = "List of subnet ids in which to create resources"
  type        = string
  default     = "subnet-5170c50c, subnet-028c395f"
}

variable "vcs" {
  description = "A link to the repo in a version control system (usually Git) that manages this resource."
  type        = string
  default     = "gitlab"
}

variable "vpc_id" {
  description = "The ID of the VPC we should use for EC2 instances"
  type        = string
  default     = "vpc-800e4cf8"
}

###
# Optional
###

variable "ami_filter" {
  description = "name filter for EC2 AMI"
  default     = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-????????"
  type        = string
}

variable "ami_owner" {
  description = "Owner of the EC2 AMI"
  default     = "099720109477" # Canonical
  type        = string
}

variable "ami_user" {
  description = "default user for the EC2 AMI"
  default     = "ubuntu"
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}


variable "compliance_risk" {
  description = "Should be `none`, `ferpa` or `pii`"
  default     = "none"
}

variable "data_risk" {
  description = "Should be `low`, `medium` or `high` based on data-risk classifications defined in VT IT Policies"
  default     = "low"
}

variable "documentation" {
  description = "Link to documentation and/or history file"
  default     = "none"
}

variable "environment" {
  description = "e.g. `development`, `test`, or `production`"
  default     = "dev"
}

variable "gitlab_runner_version" {
  description = "version string for the gitlab runner to install"
  default     = "latest"
}

variable "gitlab_config_secret_id" {
  description = "AWS Secrets Manager secret id for secret containing your complete gitlab runner config"
  default     = "none"
}

variable "gitlab_token" {
  description = "Gitlab token for your group or project"
  default     = "wJJ1cvcHg_6_eY1EptJd"
}

variable "gitlab_url" {
  description = "URL to the Gitlab instance the runner will serve"
  default     = "https://gitlab.com/"
}

variable "instance_type" {
  description = "The EC2 instance type to use for the docker machines"
  default     = "t2.large"
}

variable "log_retention" {
  description = "Number of days to keep logs from Docker Machines created by gitlab-runner"
  default     = 14
}

variable "machine_iam_instance_profile" {
  description = "Name of an AWS IAM role name to assign as the profile for new instances"
  default     = ""
}

variable "machine_idle_nodes" {
  description = "Maximum idle machines"
  default     = 0
}

variable "machine_idle_time" {
  description = "Minimum time after node can be destroyed"
  default     = 300
}

variable "machine_max_builds" {
  description = "Maximum number of builds processed by machine"
  default     = 10
}

variable "machine_off_peak_idle_nodes" {
  description = "Maximum idle machines when the scheduler is in the OffPeak mode"
  default     = 0
}

variable "machine_off_peak_idle_time" {
  description = "Minimum time after machine can be destroyed when the scheduler is in the OffPeak mode"
  default     = 120
}

variable "machine_off_peak_timezone" {
  description = "Timezone for the OffPeak periods"
  default     = "America/New_York"
}

variable "responsible_party2" {
  description = "Backup for responsible_party"
  default     = "none"
}

variable "runner_name" {
  description = "The runner name as seen in Gitlab"
  default     = "gitlab-runner"
}

variable "runner_tags" {
  description = "Tags to apply to the GitLab Runner, comma-separated"
  default     = ""
}

variable "service_name" {
  description = "The high level service this resource is primarily supporting"
  default     = "build"
}

variable "supervisor_instance_type" {
  description = "The EC2 instance type to use for supervisor machine"
  default     = "t3.micro"
}

variable "use_public_ip_for_bastion" {
  description = "set true if you want a public ip allocated for the bastion host"
  default     = "true"
}

locals {
  service_tags = {
    Name              = "gitlab-runner-supervisor-${var.service_name}"
    Service           = var.service_name
    Environment       = var.environment
    ResponsibleParty  = var.responsible_party
    ResponsibleParty2 = var.responsible_party2
    DataRisk          = var.data_risk
    ComplianceRisk    = var.compliance_risk
    Documentation     = var.documentation
    Comments          = "Gitlab runner for ${var.service_name}/${var.environment}"
    VCS               = var.vcs
  }
}
