// VM values
@description('Enter a name for your VM.')
param vmName string = 'ado-agent1-vm'
@description('Choose a size for your VM.')
param vmSize string = 'Standard_B2s'
var vmNicName = '${vmName}-nic1'
var vmIpName = '${vmName}-ip'
@description('Enter a username for accessing your VM.')
param vmAdminUser string = 'azureuser'
@secure()
@description('Enter the password for accessing your VM.')
param vmAdminPassword string
var dnsLabelPrefix = toLower('${vmName}-${uniqueString(resourceGroup().id, vmName)}')

// VNet values
@description('Enter a name for your VNet.')
param vnetName string = 'agentpool1-vnet'
@description('Choose an address space for your VNet.')
param vnetAddressSpace string = '10.100.0.0/16'
@description('Enter a name for the subnet to be created in your VNet.')
param vnetSubnetName string = 'subnet1'
@description('Enter an address space for your subnet (within the VNet).')
param vnetSubnetSpace string = '10.100.1.0/24'
@description('Enter a name for the NSG that will protect your VNet.')
param nsgName string = 'agentpool1-nsg'

@description('Paste the PAT that you created, with permissions to deploy an agent.')
@secure()
param devOpsPAT string
@description('Paste in the URI of your Azure DevOps org (e.g. "https://dev.azure.com/ausemart").')
param devOpsUri string
@description('Enter the name of the CSE script to run (recommended to leave as-is).')
param scriptName string = 'cse-adoAgentSetup.ps1'
@description('Enter the name of the CSE script URI (recommended to leave as-is).')
param scriptUris array = ['https://raw.githubusercontent.com/jamesdplee/cloudlee-click2deploy/main/scripts/cse-adoAgentSetup.ps1']
var scriptArgs = '-devOpsUri ${devOpsUri} -devOpsPAT ${devOpsPAT}'
var scriptCmd = 'powershell -ExecutionPolicy Unrestricted -File ${scriptName} ${scriptArgs}'

// Global values
@description('Leave this as-is, for all resources to be created in the same locaiton as the resource group.')
param location string   = resourceGroup().location

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-inbound-rdp'
        properties: {
          description: 'Allows RDP inbound from all source addresses (should lock this down!)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1100
          direction: 'Inbound'
        }
      }
    ]
  }
}


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
    subnets: [
      {
        name: vnetSubnetName
        properties: {
          addressPrefix: vnetSubnetSpace
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: vmIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}


resource networkInterface 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: vmNicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddress.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, vnetSubnetName)
          }
        }
      }
    ]
  }
}


resource windowsVMGuestConfigExtension 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  parent: windowsVM
  name: 'config-app'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: false
    settings: { }
    protectedSettings: { 
      fileUris: scriptUris
      commandToExecute: scriptCmd
    }
  }
}

resource windowsVM 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: vmAdminUser
      adminPassword: vmAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'microsoftvisualstudio'
        offer: 'visualstudio2022'
        sku: 'vs-2022-comm-latest-ws2022'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-disk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
  }
}
