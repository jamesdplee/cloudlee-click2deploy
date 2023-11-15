/*
  Click-to-Deploy template.

  Deploys one or more VMs with tools as required.
*/

// VM params and default values
@description('Choose how many VMs you would like to deploy.')
param vmCount int = 1
@description('Enter a name for your VM(s). If you deploy multipe VMs, this will be the prefix.')
param vmName string = 'vm'
@description('Choose a size for your VM(s).')
param vmSize string = 'Standard_B2s'
@description('Enter a username for accessing your VM(s).')
param vmAdminUser string = 'azureuser'
@secure()
@description('Enter the password for accessing your VM(s).')
param vmAdminPassword string
var dnsLabelPrefix = toLower('${vmName}-${uniqueString(resourceGroup().id, vmName)}')

// VM Extension
@description('Enter the name of the CSE script to run (recommended to leave as-is).')
param scriptName string = 'cse-vmGeneric.ps1'
@description('Enter the name of the CSE script URI (recommended to leave as-is).')
param scriptUris array = ['https://raw.githubusercontent.com/jamesdplee/cloudlee-click2deploy/main/scripts/${scriptName}']
@description('Enter any arguments you require (recommended to leave as-is).')
param scriptArgs string = ''
var scriptCmd = 'powershell -ExecutionPolicy Unrestricted -File ${scriptName} ${scriptArgs}'

// VNet values
@description('Enter a name for your VNet.')
param vnetName string = 'vnet1'
@description('Choose an address space for your VNet.')
param vnetAddressSpace string = '10.100.0.0/16'
@description('Enter a name for the subnet to be created in your VNet.')
param vnetSubnetName string = 'subnet1'
@description('Enter an address space for your subnet (within the VNet).')
param vnetSubnetSpace string = '10.100.1.0/24'
@description('Enter a name for the NSG that will protect your VNet.')
param nsgName string = 'nsg1'

// Global values
@description('Leave this as-is for all resources to be created in the same locaiton as the resource group.')
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
      {
        name: 'allow-inbound-http'
        properties: {
          description: 'Allows http inbound from all source addresses (should lock this down!)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1200
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

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = [for i in range(0, vmCount): {
  name: '${vmName}${i}-ip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${dnsLabelPrefix}${i}'
    }
  }
}]


resource networkInterface 'Microsoft.Network/networkInterfaces@2020-11-01' = [for i in range(0, vmCount): {
  name: '${vmName}${i}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddress[i].id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, vnetSubnetName)
          }
        }
      }
    ]
  }
}]

resource windowsVMGuestConfigExtension 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = [for i in range(0, vmCount): if (!empty(scriptUris)) {  
  parent: windowsVM[i]
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
}]


resource windowsVM 'Microsoft.Compute/virtualMachines@2020-12-01' = [for i in range(0, vmCount): {
  name: '${vmName}${i}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${vmName}${i}'
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
        name: '${vmName}${i}-disk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface[i].id
        }
      ]
    }
  }
}]
