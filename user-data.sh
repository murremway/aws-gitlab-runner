#!/bin/bash
set -x

####
# Setup Logging to CloudWatch
####
apt-get install -y python-minimal unzip
curl -o /tmp/awslogs-agent-setup.py https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O

# Inject the CloudWatch Logs configuration file contents
cat > /tmp/awslogs.conf <<- EOF
[general]
state_file = /var/awslogs/state/agent-state

[/var/log/syslog]
file = /var/log/syslog
log_stream_name = ec2/{container_instance_id}/var/log/syslog
log_group_name = ${log_group}

[/var/log/cloud-init-output.log]
file = /var/log/cloud-init-output.log
log_stream_name = ec2/{container_instance_id}/var/log/cloud-init-output.log
log_group_name = ${log_group}
EOF
container_instance_id=$(curl 169.254.169.254/latest/meta-data/instance-id)
sed -i -e "s/{container_instance_id}/$container_instance_id/g" /tmp/awslogs.conf

python /tmp/awslogs-agent-setup.py --non-interactive --region ${region} --configfile=/tmp/awslogs.conf
service awslogs start
rm /tmp/awslogs.conf /tmp/awslogs-agent-setup.py

####
# Docker
####
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

if [ -z "$(apt-key fingerprint 0EBFCD88 2>/dev/null)" ]; then
  echo "Invalid fingerprint for Docker GPG key"
  exit 1
fi

add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Docker Machine
base=https://github.com/docker/machine/releases/download/v0.16.0 &&
  curl -L $base/docker-machine-$(uname -s)-$(uname -m) >/tmp/docker-machine &&
  sudo mv /tmp/docker-machine /usr/local/bin/docker-machine &&
  chmod +x /usr/local/bin/docker-machine

####
# Gitlab Runner 
####

# Install the runner
runner_deb=gitlab-runner_amd64.deb
curl --silent --location --remote-name --remote-header-name https://gitlab-runner-downloads.s3.amazonaws.com/${runner_version}/deb/$runner_deb
dpkg -i $runner_deb
rm -f $runner_deb

if [ "${token}" == "none" -a "${config_secret_id}" == "none" ]; then
  echo "You must provide either a gitlab token or a config secret id"
  exit 1
fi


if [ "${config_secret_id}" != "none" ]; then
  ####
  # Install AWS CLI
  ####
  cd /tmp
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install

  # Fetch the secrete from secrets manager
  aws --region=${region} secretsmanager get-secret-value --secret-id ${config_secret_id} --query SecretString --output text > /tmp/gitlab-config.toml
  [ -f /etc/gitlab-runner/config.toml ] && mv /etc/gitlab-runner/config.toml /etc/gitlab-runner/config.toml.orig
  mv /tmp/gitlab-config.toml /etc/gitlab-runner/config.toml
  gitlab-runner restart

elif [ "${token}" != "none" ]; then
  # Register the runner
  cat >/tmp/gitlab-register.sh <<EOF
export gitlab_url="${gitlab_url}"
export token="${token}"
export runner_name="${runner_name}"
export cache_bucket="${cache_bucket}"
export region="${region}"
export vpc_id="${vpc_id}"
export subnet_id="${subnet_id}"
export security_group="${security_group}"
export instance_type="${instance_type}"
export subnet_az="${subnet_az}"
export tags="$(echo ${tags} |sed 's/,$//')"

gitlab-runner register \
  --non-interactive \
  --url "${gitlab_url}" \
  --registration-token "${token}" \
  --executor "docker+machine" \
  --docker-image docker:stable \
  --description "${runner_name}" \
  --locked="false" \
  --tag-list "${runner_tags}" \
  --docker-disable-cache="true" \
  --docker-privileged="true" \
  --docker-volumes "/cache" \
  --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
  --cache-type "s3" \
  --cache-shared="true" \
  --cache-s3-server-address "s3.amazonaws.com" \
  --cache-s3-bucket-name "${cache_bucket}" \
  --cache-s3-bucket-location "${region}" \
  --machine-idle-nodes ${idle_nodes} \
  --machine-idle-time ${idle_time} \
  --machine-max-builds ${max_builds} \
  --machine-off-peak-timezone "${off_peak_timezone}" \
  --machine-off-peak-idle-count ${off_peak_idle_nodes} \
  --machine-off-peak-idle-time ${off_peak_idle_time} \
  --machine-off-peak-periods '* * 0-6,18-23 * * mon-fri *' \
  --machine-off-peak-periods '* * * * * sat,sun *' \
  --machine-machine-driver "amazonec2" \
  --machine-machine-name "${runner_name}-%s" \
  --machine-machine-options "amazonec2-ami=${ami}" \
  --machine-machine-options "amazonec2-region=${region}" \
  --machine-machine-options "amazonec2-vpc-id=${vpc_id}" \
  --machine-machine-options "amazonec2-subnet-id=${subnet_id}" \
  --machine-machine-options "amazonec2-zone=${subnet_az}" \
  --machine-machine-options "amazonec2-use-private-address=true" \
  --machine-machine-options "amazonec2-tags=runner-manager-name,gitlab-aws-autoscaler,gitlab,true,gitlab-runner-autoscale,true" \
  --machine-machine-options "amazonec2-security-group=${security_group}" \
  --machine-machine-options "amazonec2-instance-type=${instance_type}" \
  --machine-machine-options "amazonec2-iam-instance-profile=${iam_instance_profile}" \
  --machine-machine-options "amazonec2-tags=\$tags" 
EOF

  chmod u+x /tmp/gitlab-register.sh
  /tmp/gitlab-register.sh

  ####
  # Shutdown
  ####

  cat > /etc/rc6.d/K99_gitlab_unregister <<EOF
set -x
# Unregister all runners 
gitlab-runner unregister --all-runners
EOF

fi # elif [ "${token}" != "none" ]; then

####
# Stop all machines when shutting down
####
cat > /etc/rc6.d/K99_gitlab_stop_all_machines <<EOF
set -x
# Shutdown all docker machines
for machine in $(docker-machine ls -q); do
  docker-machine stop $machine
  docker-machine rm -f $machine
done
EOF
chmod a+x /etc/rc6.d/K99*
