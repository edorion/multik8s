#!/bin/bash

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

# Install Caddy
multipass exec pmaster -- sudo apt install caddy -y
multipass exec pmaster -- sudo cp /home/ubuntu/.kube/Caddyfile /etc/caddy/Caddyfile
multipass exec pmaster -- sudo systemctl restart caddy

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
multipass exec pmaster -- microk8s enable metallb:192.168.1.50-192.168.1.60
#https://www.robert-jensen.dk/posts/2021-microk8s-with-traefik-and-metallb/
multipass exec pmaster -- helm repo add traefik https://traefik.github.io/charts
multipass exec pmaster -- helm repo add bitnami https://charts.bitnami.com/bitnami
multipass exec pmaster -- helm repo update
multipass exec pmaster -- helm install traefik traefik/traefik -n traefik --create-namespace
multipass exec pmaster -- helm install external-dns bitnami/external-dns - external-dns-gcp --create-namespace -f externalDnsValues.yaml 
multipass exec pmaster -- sudo microk8s enable dns
#multipass exec pmaster -- sudo microk8s enable dashboard
multipass exec pmaster -- sudo microk8s enable hostpath-storage

# Join the nodes
#multipass exec pmaster -- sudo microk8s add-node --format json > ./workerkube/add-node
#multipass exec pworker1 -- sudo microk8s join $(jq -r '.urls[0]' < ./workerkube/add-node)
#multipass restart pmaster pworker1

# install K8's management tooling - Headlamp, ELK, Cribl
echo "###### Installing Headlamp & Cribl ######"
multipass exec pmaster -- helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
multipass exec pmaster -- helm install headlamp headlamp/headlamp -f /home/ubuntu/.kube/headlampValues.yaml --namespace kube-system
multipass exec pmaster -- helm repo add cribl https://criblio.github.io/helm-charts/
multipass exec pmaster -- helm install -f /home/ubuntu/.kube/CriblValues.yaml

# install Vault
#echo "###### Installing Vault ######"
#multipass exec pmaster -- kubectl create namespace vault
#multipass exec pmaster -- helm repo add hashicorp https://helm.releases.hashicorp.com
#export VAULT_K8S_NAMESPACE="vault" export VAULT_HELM_RELEASE_NAME="vault"
#multipass exec pmaster -- helm install -n $VAULT_K8S_NAMESPACE $VAULT_HELM_RELEASE_NAME hashicorp/vault -f /home/ubuntu/.kube/VaultOverrides.yaml
#while [ $? -ne 2 ]; do echo "still testing"; multipass exec pmaster -- kubectl -n $VAULT_K8S_NAMESPACE exec vault-0 -- vault status; done
#multipass exec pmaster -- kubectl -n $VAULT_K8S_NAMESPACE exec vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json
#VAULT_UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")
#multipass exec pmaster -- kubectl -n $VAULT_K8S_NAMESPACE exec vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY

# Install AWX
echo "###### Installing AWX ######"
multipass exec pmaster -- helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/
multipass exec pmaster -- helm install my-awx-operator awx-operator/awx-operator -n awx --create-namespace -f /home/ubuntu/.kube/AWX.yaml

# install Homepage
echo "###### Installing Homepage ######"
multipass exec pmaster -- helm repo add jameswynn https://jameswynn.github.io/helm-charts
multipass exec pmaster -- helm repo update
multipass exec pmaster -- helm install homepage jameswynn/homepage -f /home/ubuntu/.kube/homepageValues.yaml

# install test nginx app
#multipass exec pmaster -- kubectl apply -f ./.kube/mysite.yaml

date
