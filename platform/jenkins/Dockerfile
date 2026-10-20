FROM jenkins/jenkins:lts

USER root

# Python (tests + Snyk dependency scan), Docker CLI, kubectl, AWS CLI v2 (for EKS), Snyk CLI
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg unzip python3 python3-venv python3-pip \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list \
 && apt-get update && apt-get install -y --no-install-recommends docker-ce-cli \
 && curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
 && curl -fsSLo /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
 && unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/aws /tmp/awscliv2.zip \
 && curl -fsSLo /usr/local/bin/snyk https://static.snyk.io/cli/latest/snyk-linux \
 && chmod +x /usr/local/bin/kubectl /usr/local/bin/snyk \
 && rm -rf /var/lib/apt/lists/*

USER jenkins
