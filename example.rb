#!/usr/bin/env ruby

require 'azure_mgmt_resources'
require 'azure_mgmt_key_vault'
require 'dotenv'

Dotenv.load(File.join(__dir__, './.env'))

REGION = 'West US'
RESOURCE_GROUP_NAME = 'KeyVaultSample'
VAULT_NAME = 'KeyVaultSample123'

# This script expects that the following environment vars are set:
#
# AZURE_TENANT_ID: with your Azure Active Directory tenant id or domain
# AZURE_CLIENT_ID: with your Azure Active Directory Application Client ID
# AZURE_CLIENT_SECRET: with your Azure Active Directory Application Secret
# AZURE_SUBSCRIPTION_ID: with your Azure Subscription Id
#
def run_example
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

  #
  # Register your subscription for 'Microsoft.KeyVault' namespace
  #
  provider = resource_client.providers.register('Microsoft.KeyVault')
  puts "#{provider.namespace} #{provider.registration_state}"

  #
  # Create a resource group
  #
  create_resource_group(resource_client)

  #
  # Create a key vault
  #
  puts 'Create Key Vault'
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
  print_item(vault)

  #
  # list top x vaults
  #
  puts 'List top 5 Vaults'
  vaults = keyvault_client.vaults.list(5)
  vaults.each do |vault|
    print_item(vault)
  end

  #
  # delete a vault
  #
  puts 'Delete a vault'
  puts 'Press any key to continue...'
  gets
  keyvault_client.vaults.delete(RESOURCE_GROUP_NAME, VAULT_NAME)

  #
  # delete resource group
  #
  puts 'Vault has been deleted. Now delete resource group'
  puts 'Press any key to continue...'
  gets
  delete_resource_group(resource_client)
end

def create_resource_group(resource_client)
  puts 'Create a resource group'
  resource_group_params = Azure::ARM::Resources::Models::ResourceGroup.new.tap do |rg|
    rg.location = REGION
  end

  resource_group = resource_client.resource_groups.create_or_update(RESOURCE_GROUP_NAME, resource_group_params)
  print_item resource_group
end

def delete_resource_group(resource_client)
  puts 'Delete a resource group'
  resource_client.resource_groups.delete(RESOURCE_GROUP_NAME)
end

def print_item(item)
  puts "\tName: #{item.name}"
  puts "\tId: #{item.id}"
  puts "\tLocation: #{item.location}"
  puts "\tTags: #{item.tags}"
  print_properties(item.properties) if item.respond_to?(:properties)
end

def print_properties(props)
  if props.respond_to? :provisioning_state
    puts "\tProperties:"
    puts "\t\tProvisioning State: #{props.provisioning_state}"
  end
end

if $0 == __FILE__
  run_example
end
