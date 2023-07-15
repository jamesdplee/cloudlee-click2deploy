// VM values
@description('Enter a name for your first web VM')
param vm1Name string = 'dev1-vm'
@description('Choose a size for your VMs.')
param vmSize string = 'Standard_B2s'
var vm1NicName = '${vm1Name}-nic1'
var vm1IpName = '${vm1Name}-ip'
@description('Enter a username for accessing your VMs.')
param vmAdminUser string = 'azureuser'
@secure()
@description('Enter the password for accessing your VMs.')
param vmAdminPassword string
var dnsLabelPrefixVM1 = toLower('${vm1Name}-${uniqueString(resourceGroup().id, vm1Name)}')

// Cloud Init for VM - Docker and Azure CLI
var cloudInit = base64(loadTextContent('../scripts/customdata-DockerAzCLI.yml'))

// VNet values
@description('Enter a name for your shared VNet.')
param vnetName string = 'dev-vnet'
@description('Choose an address space for your VNet.')
param vnetAddressSpace string = '10.10.0.0/16'
@description('Enter a name for the subnet to be created in your VNet.')
param vnetSubnetName string = 'subnet1'
@description('Enter an address space for your subnet (within the VNet).')
param vnetSubnetSpace string = '10.10.1.0/24'
@description('Enter a name for the NSG that will protect your VNet.')
param nsgName string = 'dev-nsg'

// ACR
@minLength(5)
@maxLength(50)
@description('Provide a unique name for Azure Container Registry (or let it autogenerate)')
param acrName string = 'acr${uniqueString(resourceGroup().id)}'
@description('Provide a tier of your Azure Container Registry.')
param acrSku string = 'Basic'

// Global values
@description('Leave this as-is, for all resources to be created in the same locaiton as the resource group.')
param location string   = resourceGroup().location

resource acrResource 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: true
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-inbound-ssh'
        properties: {
          description: 'Allows SSH inbound from all source addresses (should lock this down!)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
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

resource linuxVM1 'Microsoft.Compute/virtualMachines@2020-12-01' = {
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
      customData: cloudInit
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
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
