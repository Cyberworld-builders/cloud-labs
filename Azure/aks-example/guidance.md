To help you set up a similar environment in a sandbox Azure account using Terraform, I'll provide a basic Terraform configuration that mirrors the key components of your scenario: an AKS cluster, an Azure Key Vault, and the necessary configurations for using the CSI Secrets Store driver to access secrets. This setup will use a different Azure subscription and resource group, tailored for a sandbox environment.

Note that you'll need to adjust specific values (e.g., names, regions, subscription IDs) to match your sandbox Azure account credentials and requirements. I'll also assume you're using a basic setup for simplicity, but you can expand it as needed.

* * * * *

Prerequisites:

-   An Azure subscription for your sandbox account with appropriate permissions (Contributor or higher).

-   Terraform installed (v1.0 or later).

-   Azure CLI installed and logged in (az login) to your sandbox account.

-   The azuread and azurerm Terraform providers configured.

* * * * *

Terraform Code:

1\. Provider Configuration (providers.tf):

hcl

```
provider "azurerm" {
  features {}
  subscription_id = "your-sandbox-subscription-id"  # Replace with your sandbox subscription ID
}

provider "azuread" {
  # Use default configuration or specify tenant_id if needed
}
```

2\. Resource Group (main.tf):

Create a resource group for your sandbox environment:

hcl

```
resource "azurerm_resource_group" "rg_sandbox" {
  name     = "rg-sandbox-utopia-dev"
  location = "West US 2"  # Adjust region as needed
}
```

3\. Azure Key Vault (main.tf):

Create a Key Vault to store secrets, similar to WUS2-UTOPIA-DEV-EXT-KV:

hcl

```
resource "azurerm_key_vault" "kv_sandbox" {
  name                        = "wus2-sandbox-utopia-dev-kv"
  location                    = azurerm_resource_group.rg_sandbox.location
  resource_group_name         = azurerm_resource_group.rg_sandbox.name
  tenant_id                   = "your-tenant-id"  # Replace with your Azure AD tenant ID
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = "your-tenant-id"  # Replace with your Azure AD tenant ID
    object_id = azurerm_user_assigned_identity.aks_identity.principal_id  # Link to AKS identity below

    secret_permissions = [
      "get",
      "list",
      "set",
    ]
  }
}

# Add a sample secret to the Key Vault (similar to tyson-testing)
resource "azurerm_key_vault_secret" "test_secret" {
  name         = "tyson-testing"
  value        = "sandbox-secret-value"
  key_vault_id = azurerm_key_vault.kv_sandbox.id
}
```

4\. AKS Cluster with Managed Identity (main.tf):

Create an AKS cluster with a system-assigned managed identity, similar to UTOPIA-akscluster-Dev:

hcl

```
resource "azurerm_kubernetes_cluster" "aks_sandbox" {
  name                = "utopia-akscluster-sandbox"
  location            = azurerm_resource_group.rg_sandbox.location
  resource_group_name = azurerm_resource_group.rg_sandbox.name
  dns_prefix          = "utopia-sandbox"

  default_node_pool {
    name       = "agentpool"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"  # Use Azure CNI for network integration
  }
}
```

5\. User-Assigned Managed Identity (Optional):

If you prefer a user-assigned managed identity (more flexible for the CSI driver), add this:

hcl

```
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "aks-sandbox-identity"
  resource_group_name = azurerm_resource_group.rg_sandbox.name
  location            = azurerm_resource_group.rg_sandbox.location
}

# Assign the identity to the AKS cluster (if using user-assigned)
resource "azurerm_kubernetes_cluster" "aks_sandbox" {
  # ... (previous AKS config) ...
  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }
  # ... (rest of AKS config) ...
}
```

6\. Assign Key Vault Permissions to AKS Identity:

Ensure the AKS identity (system-assigned or user-assigned) has permissions on the Key Vault:

hcl

```
resource "azurerm_role_assignment" "kv_access" {
  scope                = azurerm_key_vault.kv_sandbox.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.aks_sandbox.identity[0].principal_id  # For system-assigned
  # or principal_id = azurerm_user_assigned_identity.aks_identity.principal_id  # For user-assigned
}
```

7\. CSI Secrets Store Driver Integration:

You'll need to install the CSI Secrets Store driver in the AKS cluster after creation. This isn't managed directly by Terraform but can be done via Helm or kubectl. Here's a placeholder for reference (you'll run this manually post-deployment):

bash

```
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system
```

8\. SecretProviderClass (Kubernetes Resource, Not Terraform):

After the AKS cluster is up, create a SecretProviderClass in Kubernetes to configure the CSI driver for Azure Key Vault (similar to your original my-spc-test). Here's an example YAML you can apply manually:

yaml

```
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: wus2-sandbox-utopia-dev-kv
  namespace: utopia-sc-akv-test  # Adjust namespace as needed for your sandbox
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useManagedIdentity: "true"
    keyvaultName: "wus2-sandbox-utopia-dev-kv"
    objects: |
      array:
        - |
          objectName: tyson-testing
          objectType: secret
    resourceGroup: "rg-sandbox-utopia-dev"
    subscriptionId: "your-sandbox-subscription-id"
    tenantId: "your-tenant-id"
```

9\. Pod Configuration (Kubernetes Resource, Not Terraform):

Create a pod to test the secret mount, similar to your testingpod:

yaml

```
apiVersion: v1
kind: Pod
metadata:
  name: testingpod-sandbox
  namespace: utopia-sc-akv-test
spec:
  containers:
    - name: busybox
      image: busybox:1.28
      command: ["sleep", "3600"]
      volumeMounts:
        - name: secrets-store-inline
          mountPath: "/mnt/secrets-store"
          readOnly: true
  volumes:
    - name: secrets-store-inline
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: wus2-sandbox-utopia-dev-kv
```

* * * * *

How to Use This Terraform Code:

1.  Initialize Terraform:

    bash

    ```
    terraform init
    ```

2.  Plan the Deployment:

    bash

    ```
    terraform plan
    ```

3.  Apply the Configuration:

    bash

    ```
    terraform apply
    ```

4.  Post-Deployment:

    -   Use kubectl or Helm to install the CSI Secrets Store driver in the AKS cluster.

    -   Apply the SecretProviderClass and pod YAML manually using kubectl apply -f <file>.yaml.

* * * * *

Notes:

-   Sandbox Account: Replace placeholders like your-sandbox-subscription-id, your-tenant-id, and resource names with values specific to your sandbox Azure account.

-   Costs: Be mindful of Azure costs in your sandbox account, especially for AKS and Key Vault. Use the smallest resource sizes (e.g., Standard_DS2_v2 for nodes) and clean up resources with terraform destroy when done.

-   Security: Ensure you secure sensitive data (e.g., subscription IDs, tenant IDs) in Terraform state files using a remote backend (e.g., Azure Blob Storage) or environment variables.

-   Permissions: Ensure your sandbox account has permissions to create AKS clusters, Key Vaults, and assign roles.

-   Testing: This setup mimics your production environment but uses sandbox-specific names and resources. Test the secret mounting process by checking the pod logs and mounted files at /mnt/secrets-store.

This Terraform code provides a foundation for your sandbox environment. Let me know if you need adjustments, additional resources (e.g., networking, RBAC), or help with the Kubernetes components!


---

Great! Since you’ve successfully applied the Terraform configuration to set up your sandbox Azure environment (AKS cluster, Key Vault, etc.), I’ll now guide you through the Helm and Kubernetes steps to install and configure the CSI Secrets Store driver, create the SecretProviderClass, and deploy a pod to test secret mounting. This will help you drill down into the Kubernetes part of your setup, mirroring the issue you’re troubleshooting in your original environment.
Prerequisites:
Ensure you have kubectl configured to connect to your sandbox AKS cluster. You can get the kubeconfig by running:
bash
az aks get-credentials --resource-group rg-sandbox-utopia-dev --name utopia-akscluster-sandbox
Install Helm (v3 or later) on your machine.
Verify the AKS cluster is running and accessible:
bash
kubectl get nodes
1. Install the CSI Secrets Store Driver Using Helm
The CSI Secrets Store driver is a Kubernetes component that enables the integration of external secret stores (like Azure Key Vault) with Kubernetes pods via the CSI framework.
Steps:
Add the Helm Repository:
Add the CSI Secrets Store driver Helm chart repository:
bash
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update
Install the Driver:
Install the driver in the kube-system namespace (default for cluster-wide components):
bash
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system
This installs the driver, including the CSI controller and node plugins, to manage secret volumes in your cluster.
Verify Installation:
Check that the driver components are running:
bash
kubectl get pods -n kube-system | grep csi-secrets-store
You should see pods like csi-secrets-store-controller-... and csi-secrets-store-node-... in a Running state.
2. Create the SecretProviderClass Resource
The SecretProviderClass defines how the CSI Secrets Store driver should interact with Azure Key Vault to retrieve secrets. This mirrors your original my-spc-test or updated wus2-utopia-dev-ext-kv configuration.
Steps:
Create the YAML File:
Save the following as secretproviderclass-sandbox.yaml (based on the Terraform setup for your sandbox):
yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: wus2-sandbox-utopia-dev-kv
  namespace: utopia-sc-akv-test  # Use the namespace from your pod setup
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useManagedIdentity: "true"
    keyvaultName: "wus2-sandbox-utopia-dev-kv"  # Matches your Terraform Key Vault name
    objects: |
      array:
        - |
          objectName: tyson-testing
          objectType: secret
    resourceGroup: "rg-sandbox-utopia-dev"  # Matches your Terraform resource group
    subscriptionId: "your-sandbox-subscription-id"  # Replace with your sandbox subscription ID
    tenantId: "your-tenant-id"  # Replace with your Azure AD tenant ID
Apply the SecretProviderClass:
Run:
bash
kubectl apply -f secretproviderclass-sandbox.yaml
Verify it’s created:
bash
kubectl get secretproviderclass wus2-sandbox-utopia-dev-kv -n utopia-sc-akv-test
Verify Permissions:
Ensure the AKS cluster’s managed identity (system-assigned or user-assigned, as deployed via Terraform) has get and list permissions on the Key Vault. You can check or assign this via Azure CLI (as shown in the Terraform code):
bash
az keyvault show --name wus2-sandbox-utopia-dev-kv --query "properties.accessPolicies"
az keyvault set-policy --name wus2-sandbox-utopia-dev-kv --object-id <aks-identity-principal-id> --secret-permissions get list --resource-group rg-sandbox-utopia-dev --subscription your-sandbox-subscription-id
3. Deploy a Test Pod
Now, deploy a pod to test mounting the secret (tyson-testing) from Azure Key Vault using the CSI Secrets Store driver.
Steps:
Create the Pod YAML:
Save the following as testpod-sandbox.yaml (based on your original testingpod but adjusted for the sandbox):
yaml
apiVersion: v1
kind: Pod
metadata:
  name: testingpod-sandbox
  namespace: utopia-sc-akv-test
spec:
  containers:
    - name: busybox
      image: busybox:1.28
      command: ["sleep", "3600"]  # Keeps the pod running for testing
      volumeMounts:
        - name: secrets-store-inline
          mountPath: "/mnt/secrets-store"
          readOnly: true
  volumes:
    - name: secrets-store-inline
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: wus2-sandbox-utopia-dev-kv
Apply the Pod:
Run:
bash
kubectl apply -f testpod-sandbox.yaml
Verify the Pod:
Check the pod status and events:
bash
kubectl describe pod testingpod-sandbox -n utopia-sc-akv-test
kubectl logs testingpod-sandbox -n utopia-sc-akv-test
Look for errors like FailedMount, failed to get secretproviderclass, or authentication issues. If successful, the secret should be mounted at /mnt/secrets-store in the pod.
Check the Mounted Secret:
Use kubectl exec to inspect the mounted secret inside the pod:
bash
kubectl exec -it testingpod-sandbox -n utopia-sc-akv-test -- cat /mnt/secrets-store/tyson-testing
You should see the value sandbox-secret-value (from the Terraform Key Vault secret).
4. Troubleshooting Tips
If you encounter issues similar to your original problem, here’s how to drill down:
Check CSI Driver Status:
Ensure the CSI Secrets Store driver pods are running:
bash
kubectl get pods -n kube-system | grep csi-secrets-store
Verify SecretProviderClass:
Confirm the SecretProviderClass is correctly applied and matches the pod configuration:
bash
kubectl get secretproviderclass wus2-sandbox-utopia-dev-kv -n utopia-sc-akv-test -o yaml
Check Authentication:
If you see failed to get credentials or similar, verify:
The AKS managed identity is correctly configured and has Key Vault permissions.
The useManagedIdentity: "true" setting in the SecretProviderClass.
Namespace and Name Consistency:
Ensure all resources (SecretProviderClass, pod) are in the utopia-sc-akv-test namespace and use consistent names (e.g., wus2-sandbox-utopia-dev-kv).
Logs for CSI Driver:
Inspect the CSI driver logs for deeper insights:
bash
kubectl logs -n kube-system <csi-secrets-store-controller-pod-name>
kubectl logs -n kube-system <csi-secrets-store-node-pod-name>
5. Additional Considerations
Namespace Creation: If utopia-sc-akv-test doesn’t exist, create it:
bash
kubectl create namespace utopia-sc-akv-test
Helm Customization: If needed, customize the CSI Secrets Store driver Helm chart (e.g., for specific Azure configurations or RBAC settings):
bash
helm show values secrets-store-csi-driver/secrets-store-csi-driver > values.yaml
Edit values.yaml and install with:
bash
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system -f values.yaml
Testing Different Authentication: If managed identity doesn’t work, you can test service principal mode by setting useManagedIdentity: "false", creating a secrets-store-creds secret, and configuring nodePublishSecretRef in the pod.
Simple Explanation for Your Sandbox Testing:
“You’ve set up the AKS cluster and Key Vault with Terraform. Now, use Helm to install the CSI Secrets Store driver in the kube-system namespace, create a SecretProviderClass for your Key Vault, and deploy a test pod to mount the tyson-testing secret. Check the pod logs and mounted files to see if it works. If there are errors, we’ll troubleshoot step-by-step, focusing on authentication, namespace, and resource names.”
Let me know if you run into specific errors or need help with any part of this process!