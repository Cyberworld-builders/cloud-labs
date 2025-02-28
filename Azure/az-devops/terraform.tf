# terraform.tf

# Configure the Azure provider (optional, if you need Azure resources for additional context)
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# # Configure the Azure DevOps provider
# provider "azuredevops" {
#   org_service_url = "https://dev.azure.com"
#   personal_access_token = var.azure_devops_pat
# }

terraform {
  required_providers {
    azuredevops = {
      source = "microsoft/azuredevops"
      version = ">= 0.1.0"
    }
  }
}

# Variables
variable "azure_devops_pat" {
  description = "Personal Access Token for Azure DevOps"
  type        = string
  sensitive   = true
}

variable "organization_name" {
  description = "Name of the Azure DevOps organization"
  type        = string
  default     = "cyberworld-builders"
}

# Create an Azure DevOps organization (optional, if you need a new one)
# Note: Creating organizations via Terraform is not directly supported; you may need to create it manually or use a script
# For this example, assume the organization exists, and we’ll work within it

# Create an Azure DevOps project
resource "azuredevops_project" "test_project" {
  name       = "TestProject"
  description = "Test project for emulating Matthew's Azure DevOps setup"
  visibility = "private"
  version_control = "Git"
  work_item_template = "Agile"
}

# Create a Git repository within the project
resource "azuredevops_git_repository" "test_repo" {
  project_id = azuredevops_project.test_project.id
  name       = "TestRepo"
  initialization {
    init_type = "Clean"
  }
}

# Create a service connection to Azure (optional, for pipeline integration with Azure resources)
resource "azuredevops_serviceendpoint_azurerm" "azure_sp" {
  project_id            = azuredevops_project.test_project.id
  service_endpoint_name = "AzureConnection"
  description           = "Service connection to Azure for pipelines"
  resource_group        = "your-resource-group" # Replace with an existing or new Azure resource group
  subscription_id       = "your-subscription-id" # Replace with your Azure subscription ID
  subscription_name     = "YourAzureSubscription"
  credentials {
    serviceprincipalid  = "your-service-principal-id" # Replace with your service principal ID
    serviceprincipalkey = "your-service-principal-key" # Replace with your service principal key
  }
}

# Create a YAML pipeline referencing the repository and a branch
resource "azuredevops_build_definition" "test_pipeline" {
  project_id = azuredevops_project.test_project.id
  name       = "TestPipeline"
  path       = "\\"

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.test_repo.id
    branch_name = "refs/heads/main"
    yml_path    = "azure-pipelines.yml"
  }

  variable {
    name  = "system.debug"
    value = "true"
  }

  ci_trigger {
    use_yaml = true
  }
}

# Upload a sample pipeline YAML file to the repository
resource "azuredevops_git_repository_file" "pipeline_yaml" {
  repository_id = azuredevops_git_repository.test_repo.id
  file          = "azure-pipelines.yml"
  content       = <<EOT
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - script: echo "Building from main branch"
    displayName: 'Run a build step'
EOT
  branch        = "main"
  commit_message = "Add initial pipeline YAML"
}

# Output the OData feed URL for querying
output "odata_feed_url" {
  value = "https://analytics.dev.azure.com/${var.organization_name}/${azuredevops_project.test_project.name}/_odata/v4.0-preview/"
  description = "URL for the Azure DevOps Analytics OData feed to query Branches and PipelineRuns"
}