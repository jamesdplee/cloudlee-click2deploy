// VM values
@description('Enter a name for your first web VM')
param vm1Name string = 'web1-vm'
@description('Enter a name for your second web VM')
param vm2Name string = 'web2-vm'
@description('Choose a size for your VMs.')
param vmSize string = 'Standard_B2s'
var vm1NicName = '${vm1Name}-nic1'
var vm1IpName = '${vm1Name}-ip'
var vm2NicName = '${vm2Name}-nic1'
var vm2IpName = '${vm2Name}-ip'
@description('Enter a username for accessing your VMs.')
param vmAdminUser string = 'azureuser'
@secure()
@description('Enter the password for accessing your VMs.')
param vmAdminPassword string
var dnsLabelPrefixVM1 = toLower('${vm1Name}-${uniqueString(resourceGroup().id, vm1Name)}')
var dnsLabelPrefixVM2 = toLower('${vm2Name}-${uniqueString(resourceGroup().id, vm2Name)}')

// VNet values
@description('Enter a name for your shared VNet.')
param vnetName string = 'web-vnet'
@description('Choose an address space for your VNet.')
param vnetAddressSpace string = '10.10.0.0/16'
@description('Enter a name for the subnet to be created in your VNet.')
param vnetSubnetName string = 'subnet1'
@description('Enter an address space for your subnet (within the VNet).')
param vnetSubnetSpace string = '10.10.1.0/24'
@description('Enter a name for the NSG that will protect your VNet.')
param nsgName string = 'web-nsg'

// CSE for Web Server setup with Aus-E-Mart installation
@description('Enter the name of the CSE script to run (recommended to leave as-is).')
param scriptName string = 'cse-vmAEMWebAppSetup.ps1'
@description('Enter the name of the CSE script URI (recommended to leave as-is).')
param scriptUris array = ['https://raw.githubusercontent.com/jamesdplee/cloudlee-click2deploy/main/scripts/${scriptName}']
var scriptArgs = ''
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

resource publicIPAddress1 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: vm1IpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefixVM1
    }
  }
}

resource publicIPAddress2 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: vm2IpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefixVM2
    }
  }
}

resource networkInterface1 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: vm1NicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddress1.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, vnetSubnetName)
          }
        }
      }
    ]
  }
}

resource networkInterface2 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: vm2NicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddress2.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, vnetSubnetName)
          }
        }
      }
    ]
  }
}

resource windowsVMCSE1 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  parent: windowsVM1
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

resource windowsVMCSE2 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  parent: windowsVM2
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

resource windowsVM1 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vm1Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vm1Name
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
        name: '${vm1Name}-disk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface1.id
        }
      ]
    }
  }
}


resource windowsVM2 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vm2Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vm2Name
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
        name: '${vm2Name}-disk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface2.id
        }
      ]
    }
  }
}
