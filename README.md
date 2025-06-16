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


For inital install, remove/comment out awx_secret_key from AWX.yaml or create a awx_secret_key.yaml with contents like the following

```
---
apiVersion: v1
kind: Secret
metadata:
  name: custom-awx-secret-key
  namespace: awx
stringData:
  secret_key: ***********
```