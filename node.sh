#!/bin/bash
# Replace this with the token
TOKEN=51e7ee.a6828064abd80d03

MASTER_IP=46.101.44.189

apt-get update && apt-get upgrade -y

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update -y

apt-get install -y docker.io
apt-get install -y --allow-unauthenticated kubelet kubeadm kubectl kubernetes-cni

kubeadm join --token $TOKEN $MASTER_IP:6443

cd /root
git clone https://github.com/nabadger/simple-kube-stack.git 
cd simple-kube-stack
docker build -t simple-node-server:v1 .
./scripts/build-docker-image
#./scripts/update-kube-deployment
