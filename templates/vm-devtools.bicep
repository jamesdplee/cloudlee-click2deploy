/*
  Click-to-Deploy template.

  Deploys a VM with Visual Studio, and all required resources such
  as VNet, NIC, IP, etc.
*/

// VM params and default values
param vmName string = 'web1-vm'
param vmSize string = 'Standard_B2s'
var vmNicName = '${vmName}-nic1'
var vmIpName = '${vmName}-ip'
param vmAdminUser string = 'azureuser'
@secure()
param vmAdminPassword string
var dnsLabelPrefix = toLower('${vmName}-${uniqueString(resourceGroup().id, vmName)}')

// VNet values
param vnetName string = 'vnet1'
param vnetAddressSpace string = '10.100.0.0/16'
param vnetSubnetName string = 'subnet1'
param vnetSubnetSpace string = '10.100.1.0/24'
param nsgName string = 'nsg1'

// Global values
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
        name: 'allow-inbound-web'
        properties: {
          description: 'Allows web inbound from all source addresses (should lock this down!)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80,443'
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
