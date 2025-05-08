#### get init root password
kubectl get secret -n awx awx-admin-password -o jsonpath="{.data.password}" | base64 --decode ; echo

#### setup

###
- init users
  - self
  - terraform


- Org
- Team
- User
- Project
    - Source control URL
- creds
    - source control  - 
    - ssh - 