#!/bin/zsh

# to pick over for improvments https://github.com/arashkaffamanesh/kubeadm-multipass i.e. https://mkcert.org/

date
mkdir masterkube >/dev/null 2>&1
mkdir workerkube >/dev/null 2>&1

#Move deployment yaml's to master storage
cp ./toProvision/* ./masterkube/

# Cleanup existing images
multipass delete --all -p

# Init K8's host containers
multipass launch -m 8Gb -d 150G -c 4 -n pmaster --mount ./masterkube:/home/ubuntu/.kube
#multipass launch -m 8Gb -d 150G -c 4 -n pworker1 --mount ./workerkube:/home/ubuntu/.kube

# Install Microk8's
multipass exec pmaster -- sudo snap install microk8s --classic
multipass exec pmaster -- sudo snap install helm --classic
multipass exec pmaster -- sudo snap alias microk8s.kubectl kubectl
multipass exec pmaster -- sudo snap install kubeadm --classic
#multipass exec pworker1 -- sudo snap install microk8s --classic
#multipass exec pworker1 -- sudo snap install helm --classic
#multipass exec pworker1 -- sudo snap alias microk8s.kubectl kubectl

# Make the user a sudoer, disable firewall within the vm and enable k8 dashboard and storage.
multipass exec pmaster -- sudo usermod -a -G microk8s ubuntu
#multipass exec pworker1 -- sudo usermod -a -G microk8s ubuntu
multipass exec pmaster -- sudo microk8s config > ./masterkube/config
#multipass exec pworker1 -- sudo microk8s config > ./workerkube/config
multipass exec pmaster -- sudo ufw disable
#multipass exec pworker1 -- sudo ufw disable
multipass exec pmaster -- sudo microk8s enable community
multipass exec pmaster -- microk8s enable metallb:192.168.64.192-192.168.64.200
#https://www.robert-jensen.dk/posts/2021-microk8s-with-traefik-and-metallb/
multipass exec pmaster -- sudo microk8s enable ingress
multipass exec pmaster -- helm repo add traefik https://helm.traefik.io/traefik
multipass exec pmaster -- helm repo update
multipass exec pmaster -- helm show values traefik/traefik > traefik-values.yaml
multipass exec pmaster -- helm install traefik traefik/traefik -n traefik --create-namespace
multipass exec pmaster -- sudo microk8s enable dns
multipass exec pmaster -- sudo microk8s enable dashboard
multipass exec pmaster -- sudo microk8s enable hostpath-storage

# Join the nodes
#multipass exec pmaster -- sudo microk8s add-node --format json > ./workerkube/add-node
#multipass exec pworker1 -- sudo microk8s join $(jq -r '.urls[0]' < ./workerkube/add-node)
#multipass restart pmaster pworker1

# install K8's management tooling - Headlamp & ELK stack
multipass exec pmaster -- helm repo add headlamp https://headlamp-k8s.github.io/headlamp/
multipass exec pmaster -- helm install my-headlamp headlamp/headlamp --namespace kube-system
multipass exec pmaster -- kubectl apply -f https://raw.githubusercontent.com/kinvolk/headlamp/main/kubernetes-headlamp.yaml

#install postgress
multipass exec pmaster -- helm install my-release oci://registry-1.docker.io/bitnamicharts/postgresql

#install BoundaryController
multipass exec pmaster -- kubectl apply -f ./.kube/boundaryControllerConfigMap.yaml
multipass exec pmaster -- kubectl apply -f ./.kube/boundaryController.yaml

# install test nginx app
#multipass exec pmaster -- kubectl apply -f ./.kube/mysite.yaml

# install Vault
multipass exec pmaster -- helm repo add hashicorp https://helm.releases.hashicorp.com
multipass exec pmaster -- helm install vault hashicorp/vault --set='server.ha.enabled=true' --set='server.ha.raft.enabled=true'
multipass exec pmaster -- kubectl exec vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json
multipass exec pmaster -- VAULT_UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")
multipass exec pmaster -- kubectl exec vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY



date
