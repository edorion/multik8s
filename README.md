Work in progress, ephemeral k8's local dev lab skeleton based on:

- multipass
- microk8s
  - Metallb
  - traefik

Including:
- Boundary
- Vault
- postgress
- elastics
- fluentd
- fluentb bit
- headlamp


For inital install, remove/comment out awx_secret_key from AWX.yaml or create a awx_secret_key.py with contents like the following

```
AWX_SECRET_KEY = "******************value***********************"
```