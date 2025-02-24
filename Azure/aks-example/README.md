# AKS Example

## Useful Commands

### Azure

**Login**
```sh
az login
```

**List Accounts**
```sh
az account list --output table
```

**List Tenants**
```sh
az account tenant list
```

**Get your signed in user id**
```sh
az ad signed-in-user show --query id -o tsv
```

**Get credentials to use `kubectl`**
```sh
az aks get-credentials --resource-group rg-sandbox-utopia-dev --name utopia-akscluster-sandbox
```

### Terraform 

**Initialize**
```sh
terraform init
```

**Plan**
```sh
terraform plan
```

**Apply**
```sh
terraform apply
```

### Kubernetes

**Get nodes**
```sh
kubectl get nodes
```

**Add secret store csi driver with Helm**
```sh
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update
```

**Add csi driver with Helm**
```sh
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system
```