# Initialize variables
# Run 'doctl compute region list' for a list of available regions
REGION=lon1

# Generate SSH Keys
ssh_key_file="/Users/nick/.ssh/k8s_do_id_rsa"
ssh-keygen -t rsa -f $ssh_key_file

# Import SSH Keys
doctl compute ssh-key import k8s-ssh --public-key-file ${ssh_key_file}.pub
SSH_ID=`doctl compute ssh-key list | grep "k8s-ssh" | cut -d' ' -f1`
SSH_KEY=`doctl compute ssh-key get $SSH_ID --format FingerPrint --no-header`

# Create Tags
doctl compute tag create k8s-master
doctl compute tag create k8s-node

# Generate token and insert into the script files
TOKEN=`python -c 'import random; print "%0x.%0x" % (random.SystemRandom().getrandbits(3*8), random.SystemRandom().getrandbits(8*8))'`
sed -i.bak "s/^TOKEN=.*/TOKEN=${TOKEN}/" ./master.sh
sed -i.bak "s/^TOKEN=.*/TOKEN=${TOKEN}/" ./node.sh

# Create Master
doctl compute droplet create master \
	--region $REGION \
	--image ubuntu-16-04-x64 \
	--size 1gb \
	--tag-name k8s-master \
	--ssh-keys $SSH_KEY \
	--user-data-file  ./master.sh \
	--wait

# Retrieve IP address of Master
MASTER_ID=`doctl compute droplet list | grep "master" |cut -d' ' -f1`
MASTER_IP=`doctl compute droplet get $MASTER_ID --format PublicIPv4 --no-header`

# Run this after a few minutes. Wait till Kubernetes Master is up and running
echo "Waiting for 3 minutes seconds for kubernetes to install on master"
sleep 120 


# Update Script with MASTER_IP
sed -i.bak "s/^MASTER_IP=.*/MASTER_IP=${MASTER_IP}/" ./node.sh

# Create nodes - sleep for a bit to wait for sshd to start
doctl compute droplet create node1 \
	--region $REGION \
	--image ubuntu-16-04-x64 \
	--size 1gb \
	--tag-name k8s-node \
	--ssh-keys $SSH_KEY \
	--user-data-file  ./node.sh \
	--wait
sleep 60

scp -i $ssh_key_file root@$MASTER_IP:/etc/kubernetes/admin.conf $HOME/.kube/config

# Copy master admin config to all nodes
NODE_IDS=`doctl compute droplet list | grep "node"| cut -d' ' -f1`
while read -r node_id; do 
    node_ip=`doctl compute droplet get $node_id --format PublicIPv4 --no-header`
    ssh -i $ssh_key_file root@$node_ip mkdir -p .kube
    scp -i $ssh_key_file $HOME/.kube/config root@$node_ip:.kube/config
done <<< "$NODE_IDS"
