// VM values
param vmName string = 'ado-agent1-vm'
param vmSize string = 'Standard_B2s'
var vmNicName = '${vmName}-nic1'
var vmIpName = '${vmName}-ip'
param vmAdminUser string = 'azureuser'
@secure()
param vmAdminPassword string

// VNet values
param vnetName string = 'agentpool1-vnet'
param vnetAddressSpace string = '10.100.0.0/16'
param vnetSubnetName string = 'subnet1'
param vnetSubnetSpace string = '10.100.1.0/24'
param nsgName string = 'agentpool1-nsg'

@secure()
param devOpsPAT string
param devOpsUri string
param scriptName string = 'cse-adoAgentSetup.ps1'
param scriptUris array = ['https://raw.githubusercontent.com/jamesdplee/cloudlee-click2deploy/main/scripts/cse-adoAgentSetup.ps1']
var scriptArgs = '-devOpsUri ${devOpsUri} -devOpsPAT ${devOpsPAT}'
var scriptCmd = 'powershell -ExecutionPolicy Unrestricted -File ${scriptName} ${scriptArgs}'

param location string   = resourceGroup().location
var dnsLabelPrefix = toLower('${vmName}-${uniqueString(resourceGroup().id, vmName)}')

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
