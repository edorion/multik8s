#!/bin/bash

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

# Install Caddy
multipass exec pmaster -- sudo snap install --edge caddy
multipass exec pmaster -- sudo cp /home/ubuntu/.kube/Caddyfile /etc/caddy/Caddyfile
multipass exec pmaster -- sudo systemctl restart caddy

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
#multipass exec pmaster -- kubectl apply -f /home/ubuntu/.kube/headlamp.yaml

multipass exec pmaster --helm repo add cribl https://criblio.github.io/helm-charts/
multipass exec pmaster --helm install -f /home/ubuntu/.kube/CriblValues.yaml

#helm repo add elastic https://helm.elastic.co
#helm repo update
# Install an eck-managed Elasticsearch, Kibana, Beats and Logstash using custom values.
#helm install eck-stack-with-logstash elastic/eck-stack --values https://raw.githubusercontent.com/elastic/cloud-on-k8s/2.16/deploy/eck-stack/examples/logstash/basic-eck.yaml -n elastic-stack

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

# install Pi-hole
echo "###### Installing Pi-hole ######"
multipass exec pmaster -- helm repo add savepointsam https://savepointsam.github.io/charts
multipass exec pmaster -- helm repo update
multipass exec pmaster -- helm install my-release savepointsam/pihole

# install HomeAssistant
echo "###### Installing HomeAssistant ######"
multipass exec pmaster -- helm repo add pajikos http://pajikos.github.io/home-assistant-helm-chart/
multipass exec pmaster -- helm repo update
multipass exec pmaster -- helm install home-assistant pajikos/home-assistant -f /home/ubuntu/.kube/homeassistantValues.yaml
# install IT Tools
echo "###### Installing IT Tools ######"
multipass exec pmaster -- helm repo add jeffresc https://charts.jeffresc.dev
multipass exec pmaster -- helm repo update
multipass exec pmaster -- helm install it-tools jeffresc/it-tools

# install Homepage
echo "###### Installing Homepage ######"
multipass exec pmaster -- helm repo add jameswynn https://jameswynn.github.io/helm-charts
multipass exec pmaster -- helm repo update
multipass exec pmaster -- helm install homepage jameswynn/homepage -f /home/ubuntu/.kube/homepageValues.yaml

#install postgress
#multipass exec pmaster -- helm install my-release oci://registry-1.docker.io/bitnamicharts/postgresql

#install BoundaryController
#multipass exec pmaster -- kubectl apply -f ./.kube/boundaryControllerConfigMap.yaml
#multipass exec pmaster -- kubectl apply -f ./.kube/boundaryController.yaml

# install test nginx app
#multipass exec pmaster -- kubectl apply -f ./.kube/mysite.yaml

date
