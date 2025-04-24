// ------------------------------
// General Settings
// ------------------------------
@description('Region for VNet1 (Hub)')
param region1 string = 'australiaeast'

@description('Region for VNet2 (Spoke)')
param region2 string = 'australiacentral'

// ------------------------------
// VNet Configuration
// ------------------------------
@description('Name of VNet1 (Hub)')
param vnet1Name string = 'hub-vnet'

@description('Name of VNet2 (Spoke)')
param vnet2Name string = 'spoke-vnet'

var subnetName = 'subnet1'
var vnet1Prefix = '10.100.0.0/16'
var vnet2Prefix = '10.201.0.0/16'
var subnet1Prefix = '10.100.0.0/24'
var subnet2Prefix = '10.201.0.0/24'
var nsg1Name = '${region1}-default-nsg'
var nsg2Name = '${region2}-default-nsg'

// ------------------------------
// Peering
// ------------------------------
@description('Enable VNet peering between hub and spoke')
param enablePeering bool = true

// ------------------------------
// VM Configuration
// ------------------------------
@description('Enable VM creation')
param enableVMs bool = true

@description('Name of VM1 (in hub)')
param vm1Name string = 'vm1'

@description('Name of VM2 (in spoke)')
param vm2Name string = 'vm2'

@description('VM size for both VMs')
param vmSize string = 'Standard_B2s'

@description('VM Admin username')
param vmAdminUser string

@secure()
@description('VM Admin password')
param vmAdminPassword string

@description('Choose OS type')
@allowed([
  'windows2022-vs'
  'windows2019'
  'ubuntu2204'
])
param osType string = 'windows2022-vs'

var dnsLabelPrefixVM1 = toLower('${vm1Name}-${uniqueString(resourceGroup().id, vm1Name)}')
var dnsLabelPrefixVM2 = toLower('${vm2Name}-${uniqueString(resourceGroup().id, vm2Name)}')

// ------------------------------
// Optional Script Extension (CSE)
// ------------------------------
@description('Script URI array for Custom Script Extension (leave empty if unused)')
param scriptUris array = []

@description('Command to execute for CSE (leave empty if unused)')
param scriptCmd string = ''

// ------------------------------
// Image reference (based on osType)
// ------------------------------
var vmImageReference = contains([
  'windows2022-vs'
], osType) ? {
  publisher: 'microsoftvisualstudio'
  offer: 'visualstudio2022'
  sku: 'vs-2022-comm-latest-ws2022'
  version: 'latest'
} : osType == 'windows2019' ? {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2019-Datacenter'
  version: 'latest'
} : {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts-gen2'
  version: 'latest'
}

// ------------------------------
// NSGs (1 per region)
// ------------------------------
resource nsg1 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: nsg1Name
  location: region1
  properties: {
    securityRules: [
      {
        name: 'allow-inbound-rdp'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource nsg2 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: nsg2Name
  location: region2
  properties: {
    securityRules: [
      {
        name: 'allow-inbound-rdp'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
    ]
  }
}

// ------------------------------
// Virtual Networks
// ------------------------------
resource vnet1 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnet1Name
  location: region1
  properties: {
    addressSpace: { addressPrefixes: [vnet1Prefix] }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnet1Prefix
          networkSecurityGroup: { id: nsg1.id }
        }
      }
    ]
  }
}

resource vnet2 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnet2Name
  location: region2
  properties: {
    addressSpace: { addressPrefixes: [vnet2Prefix] }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnet2Prefix
          networkSecurityGroup: { id: nsg2.id }
        }
      }
    ]
  }
}

// ------------------------------
// Peering (with dependsOn)
// ------------------------------
resource peer1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = if (enablePeering) {
  name: '${vnet1Name}/peer-to-${vnet2Name}'
  dependsOn: [vnet1, vnet2]
  properties: {
    remoteVirtualNetwork: { id: vnet2.id }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}

resource peer2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = if (enablePeering) {
  name: '${vnet2Name}/peer-to-${vnet1Name}'
  dependsOn: [vnet1, vnet2]
  properties: {
    remoteVirtualNetwork: { id: vnet1.id }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}

// ------------------------------
// Public IPs and NICs
// ------------------------------
resource publicIp1 'Microsoft.Network/publicIPAddresses@2022-05-01' = if (enableVMs) {
  name: '${vm1Name}-ip'
  location: region1
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: { domainNameLabel: dnsLabelPrefixVM1 }
  }
}

resource publicIp2 'Microsoft.Network/publicIPAddresses@2022-05-01' = if (enableVMs) {
  name: '${vm2Name}-ip'
  location: region2
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: { domainNameLabel: dnsLabelPrefixVM2 }
  }
}

resource nic1 'Microsoft.Network/networkInterfaces@2022-05-01' = if (enableVMs) {
  name: '${vm1Name}-nic'
  location: region1
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: { id: publicIp1.id }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet1.name, subnetName)
          }
        }
      }
    ]
  }
}

resource nic2 'Microsoft.Network/networkInterfaces@2022-05-01' = if (enableVMs) {
  name: '${vm2Name}-nic'
  location: region2
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: { id: publicIp2.id }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet2.name, subnetName)
          }
        }
      }
    ]
  }
}

// ------------------------------
// Virtual Machines
// ------------------------------
resource vm1 'Microsoft.Compute/virtualMachines@2022-08-01' = if (enableVMs) {
  name: vm1Name
  location: region1
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: vm1Name
      adminUsername: vmAdminUser
      adminPassword: vmAdminPassword
    }
    storageProfile: {
      imageReference: vmImageReference
      osDisk: {
        name: '${vm1Name}-disk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [ { id: nic1.id } ]
    }
  }
}

resource vm2 'Microsoft.Compute/virtualMachines@2022-08-01' = if (enableVMs) {
  name: vm2Name
  location: region2
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: vm2Name
      adminUsername: vmAdminUser
      adminPassword: vmAdminPassword
    }
    storageProfile: {
      imageReference: vmImageReference
      osDisk: {
        name: '${vm2Name}-disk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [ { id: nic2.id } ]
    }
  }
}

// ------------------------------
// Optional CSE Extensions
// ------------------------------
resource vm1CSE 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = if (enableVMs && length(scriptUris) > 0 && !empty(scriptCmd)) {
  name: 'cse-${vm1Name}'
  parent: vm1
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      fileUris: scriptUris
      commandToExecute: scriptCmd
    }
  }
}

resource vm2CSE 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = if (enableVMs && length(scriptUris) > 0 && !empty(scriptCmd)) {
  name: 'cse-${vm2Name}'
  parent: vm2
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      fileUris: scriptUris
      commandToExecute: scriptCmd
    }
  }
}
