---
services: 
platforms: ruby
author: 
---

# Manage key vaults with Ruby

This sample demonstrates how to manage key vaults in Azure using the Ruby SDK.

**On this page**

- [Run this sample](#run)
- [What is example.rb doing?](#example)
    - [Create a key vault](#create)
    - [List key vaults](#list)
    - [Delete a key vault](#delete)

<a id="run"></a>
## Run this sample

1. If you don't already have it, [install Ruby and the Ruby DevKit](https://www.ruby-lang.org/en/documentation/installation/).

1. If you don't have bundler, install it.

    ```
    gem install bundler
    ```

1. Clone the repository.

    ```
    git clone https://github.com/Azure-Samples/key-vault-ruby-manage-vaults.git
    ```

1. Install the dependencies using bundle.

    ```
    cd key-vault-ruby-manage-vaults
    bundle install
    ```

1. Create an Azure service principal either through
    [Azure CLI](https://azure.microsoft.com/documentation/articles/resource-group-authenticate-service-principal-cli/),
    [PowerShell](https://azure.microsoft.com/documentation/articles/resource-group-authenticate-service-principal/)
    or [the portal](https://azure.microsoft.com/documentation/articles/resource-group-create-service-principal-portal/).

1. Set the following environment variables using the information from the service principle that you created.

    ```
    export AZURE_TENANT_ID={your tenant id}
    export AZURE_CLIENT_ID={your client id}
    export AZURE_CLIENT_SECRET={your client secret}
    export AZURE_SUBSCRIPTION_ID={your subscription id}
    ```

    > [AZURE.NOTE] On Windows, use `set` instead of `export`.

1. Run the sample.

    ```
    bundle exec ruby example.rb
    ```

<a id="example"></a>
## What is example.rb doing?

This sample starts by setting up ResourceManagementClient and KeyVaultManagementClient objects using your subscription and credentials.

```ruby
#
# Create the Resource Manager Client with an Application (service principal) token provider
#
subscription_id = ENV['AZURE_SUBSCRIPTION_ID'] || '11111111-1111-1111-1111-111111111111' # your Azure Subscription Id
provider = MsRestAzure::ApplicationTokenProvider.new(
    ENV['AZURE_TENANT_ID'],
    ENV['AZURE_CLIENT_ID'],
    ENV['AZURE_CLIENT_SECRET'])
credentials = MsRest::TokenCredentials.new(provider)

# resource client
resource_client = Azure::ARM::Resources::ResourceManagementClient.new(credentials)
resource_client.subscription_id = subscription_id

# key vault client
keyvault_client = Azure::ARM::KeyVault::KeyVaultManagementClient.new(credentials)
keyvault_client.subscription_id = subscription_id
```

It registers the subscription for the "Microsoft.Media" namespace
and creates a resource group and a storage account where the media services will be managed.

```ruby
#
# Register subscription for 'Microsoft.Media' namespace
#
provider = resource_client.providers.register('Microsoft.Media')

#
# Create a resource group
#
resource_group_params = Azure::ARM::Resources::Models::ResourceGroup.new.tap do |rg|
    rg.location = REGION
end

resource_group = resource_client.resource_groups.create_or_update(RESOURCE_GROUP_NAME, resource_group_params)
```

There are a couple of supporting functions (`print_item` and `print_properties`) that print a resource group and it's properties.
With that set up, the sample lists all resource groups for your subscription, it performs these operations.

<a id="create"></a>
### Create a key vault

```ruby
vault_param = Azure::ARM::KeyVault::Models::VaultCreateOrUpdateParameters.new
vault_param.location = REGION
vault_param.properties = Azure::ARM::KeyVault::Models::VaultProperties.new.tap do |vault_prop|
    vault_prop.tenant_id = ENV['AZURE_TENANT_ID']
    vault_prop.sku = Azure::ARM::KeyVault::Models::Sku.new.tap do |s|
        s.family = 'A'
        s.name = Azure::ARM::KeyVault::Models::SkuName::Standard
    end

    access_policy_entry = Azure::ARM::KeyVault::Models::AccessPolicyEntry.new.tap do |policy_entry|
        policy_entry.tenant_id = ENV['AZURE_TENANT_ID']
        policy_entry.object_id = ENV['AZURE_TENANT_ID']
        permission = Azure::ARM::KeyVault::Models::Permissions.new.tap do |perm|
            perm.keys = ['all']
            perm.secrets = ['all']
        end

        policy_entry.permissions = permission
    end
    vault_prop.access_policies = [access_policy_entry]
end

vault = keyvault_client.vaults.create_or_update(RESOURCE_GROUP_NAME, VAULT_NAME, vault_param)
```

<a id="list"></a>
### LIst key vaults

This code lists the first 5 key vaults.

```ruby
vaults = keyvault_client.vaults.list(5)
```

<a id="delete"></a>
### Delete a key vault

```ruby
keyvault_client.vaults.delete(RESOURCE_GROUP_NAME, VAULT_NAME)
```
