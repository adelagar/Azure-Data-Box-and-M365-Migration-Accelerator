@description('Name of the Bastion Host instance')
param BastionInstanceName string = '<Enter a unique name for your BastionHost>'

@description('Name of the Public IP Address for the Azure Bastion Host')
param BastionPublicIpAddressName string = '<Enter a unique name for your Bastion PIP>'

@description('Conditionally deploys a DNS Server with the appropriate conditional forwarder to support the Private Endpoint on the Storage Account')
param DnsServer bool = true

@description('IP Address for the Forwarder on the DNS Server.')
param DnsServerForwarderIPAddress string = ''

@description('Name of the Virtual Machine for the DNS Server.')
param DnsServerName string = ''

@description('The size of the virtual machine.')
param DnsServerSize string = 'Standard_D2s_v4'

@description('Name of the file share in Azure Files.')
param FileShareName string = 'migration-data'

@maxValue(1000)
@minValue(100)
@description('Size of the file share in Azure Files')
param FileShareSize int = 100

@description('Conditionally deploys the DNS Server with the Hybrid Use Benefit for Windows Server.')
@allowed([
  'yes'
  'no'
])
param HybridUseBenefit string = 'no'

@description('Jump Host Subnet ')
param JumpHostSubnetName string = 'JUMPHOST-SUBNET'

@description('Private Endpoint Subnet for Storage')
param PrivateEndpointSubnetName string = 'PRIVATE-ENDPOINT-SUBNET'

@description('Enter the CIDR address for the JUMP Host Subnet')
param JumpHostSubnetPrefix string = '10.230.0.0/24'

@description('CIDR address for the Azure Bastion subnet must be a /27')
param BastionSubnetPrefix string = '10.230.1.0/27'

@description('CIDR address for the Azure Bastion subnet must be a /27')
param PrivateEndpointSubnetPrefix string = '10.230.2.0/27'

@description('CIDR address for the GatewaySubnet subnet must be a /27')
param GatewaySubnetPrefix string = '10.230.3.0/27'

@secure()
@description('SAS Token for Azure Blob storage to host a private or custom version of this solution.')
param RepositorySasToken string = ''

@description('URL to the repository for the code')
param RepositoryUri string = 'https://raw.githubusercontent.com/jamasten/Azure-Data-Box-and-M365-Migration-Accelerator/main/'

@description('Name of the migration storage account. Must not be more than 24 characters, no special characters, and lowercase')
param StorageAccountName string = '<Enter your storage account name here>'

@description('The timestamp is used to rerun VM extensions when the template needs to be redeployed due to an error or update.')
param Timestamp string = utcNow()

@description('The name of the Hub virtual network provisioned for the deployment')
param VirtualNetworkName string = '<Enter the name-of-your-vnet>'

@description('Hub Virtual Network address CIDR.')
param VirtualNetworkAddressPrefix string = '10.230.0.0/21'

@description('VM Size for the Migration  Server')
@allowed([
  'Standard_DS2_v2' // should this be changed to a v4 size? // add sizes that use accelerated networking
  'Standard_DS3_v2' // should this be changed to a v4 size?
  'Standard_D4as_v4'
])
param VMSize string = 'Standard_DS2_v2'

@description('Basic name pattern of vm not more than 15 characters we are appending the numerical number at end of the vm')
param VMName string = 'M365-MIGVM'

@description('Number of Migration Computers Needed')
param VMInstances int = 2

@description('Administrative Account')
param VMUsername string = 'xadmin'

@description('Administrative Password')
@secure()
param VMPassword string

var DnsServerNetworkAddress = split(JumpHostSubnetPrefix, '/')[0]
var DnsServerOctet0 = split(DnsServerNetworkAddress, '.')[0]
var DnsServerOctet1 = split(DnsServerNetworkAddress, '.')[1]
var DnsServerOctet2 = split(DnsServerNetworkAddress, '.')[2]
var DnsServerOctet3 = split(DnsServerNetworkAddress, '.')[3]
var DnsServerIpNumber = DnsServerOctet3 == '0' ? 4 : int(DnsServerOctet3) + 4
var DnsServerIpAddress = '${DnsServerOctet0}.${DnsServerOctet1}.${DnsServerOctet2}.${DnsServerIpNumber}'
var Location = resourceGroup().location
var PrivateDnsZoneName = 'privatelink.file.${StorageSuffix}'
var PrivateEndpointName = '${StorageAccountName}-PE'
var StorageSuffix = environment().suffixes.storage

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2018-08-01' = {
  name: 'NSG-01'
  location: Location
  properties: {
    securityRules: [
      {
        name: 'RDPnsgRule'
        properties: {
          description: 'description'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: VirtualNetworkName
  location: Location
  tags: {
    displayName: VirtualNetworkName
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        VirtualNetworkAddressPrefix
      ]
    }
    dhcpOptions: {
      dnsServers: [
        DnsServer ? DnsServerIpAddress : '168.63.129.16'
      ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: BastionSubnetPrefix
        }
      }
      {
        name: JumpHostSubnetName
        properties: {
          addressPrefix: JumpHostSubnetPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
      {
        name: PrivateEndpointSubnetName
        properties: {
          addressPrefix: PrivateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: GatewaySubnetPrefix
        }
      }
    ]
  }
}

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2020-05-01' = {
  name: BastionPublicIpAddressName
  location: Location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2020-05-01' = {
  name: BastionInstanceName
  location: Location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, 'AzureBastionSubnet')
          }
          publicIPAddress: {
            id: publicIpAddress.id
          }
        }
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: StorageAccountName
  location: Location
  kind: 'FileStorage'
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
  }
}

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: false
    }
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-02-01' = {
  parent: fileServices
  name: FileShareName
  properties: {
    accessTier: 'Premium'
    shareQuota: FileShareSize
    enabledProtocols: 'SMB'
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-08-01' = {
  location: Location
  name: PrivateEndpointName
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, PrivateEndpointSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: PrivateEndpointName
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: PrivateDnsZoneName
  location: 'global'
  tags: {}
  properties: {}
  dependsOn: []
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-08-01' = {
  parent: privateEndpoint
  name: storageAccount.name
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'ipconfig1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

resource virtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${virtualNetwork.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource networkInterface_DnsServer 'Microsoft.Network/networkInterfaces@2020-05-01' = if(DnsServer) {
  name: '${DnsServerName}-NIC'
  location: Location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: DnsServerIpAddress
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, JumpHostSubnetName)
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    enableAcceleratedNetworking: false
    enableIPForwarding: false
  }
  dependsOn: []
}

resource virtualMachine_DnsServer 'Microsoft.Compute/virtualMachines@2019-07-01' = if(DnsServer) {
  name: DnsServerName
  location: Location
  properties: {
    hardwareProfile: {
      vmSize: DnsServerSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        name: '${DnsServerName}-OSDISK'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: 127
      }
      dataDisks: []
    }
    osProfile: {
      computerName: DnsServerName
      adminUsername: VMUsername
      adminPassword: VMPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
      secrets: []
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface_DnsServer.id
        }
      ]
    }
    licenseType: ((HybridUseBenefit == 'yes') ? 'Windows_Server' : json('null'))
  }
}

resource dscExtension_DnsServer 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = if(DnsServer) {
  parent: virtualMachine_DnsServer
  name: 'DSC'
  location: Location
  properties: {
    forceUpdateTag: Timestamp
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    settings: {
      modulesUrl: 'configurations/dnsForwarders.zip'
      configurationFunction: 'dnsForwarders.ps1\\dnsForwarders'
      configurationArguments: {
        ActionAfterReboot: 'ContinueConfiguration'
        ConfigurationMode: 'ApplyandAutoCorrect'
        RebootNodeIfNeeded: true
        //IPAddresses: DnsForwarderIPAddress
      }
      properties: [
        {
          Name: 'ForwarderIPAddresses'
          Value: DnsServerForwarderIPAddress
          TypeName: 'System.Array'
        }
        {
          Name: 'StorageSuffix'
          Value: StorageSuffix
          TypeName: 'System.String'
        }
      ]
    }
    protectedSettings: {}
  }
}

resource networkInterfaces_MigrationServers 'Microsoft.Network/networkInterfaces@2019-11-01' = [for i in range(0, VMInstances): {
  name: '${VMName}-NIC-${(i + 1)}'
  location: Location
  tags: {
    displayName: '${VMName}-NIC-${(i + 1)}'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, JumpHostSubnetName)
          }
        }
      }
    ]
  }
}]

resource virtualMachines_MigrationServers 'Microsoft.Compute/virtualMachines@2019-07-01' = [for i in range(0, VMInstances): {
  name: '${VMName}-${(i + 1)}'
  location: Location
  tags: {
    displayName: '${VMName}${(i + 1)}'
  }
  properties: {
    hardwareProfile: {
      vmSize: VMSize
    }
    osProfile: {
      computerName: '${VMName}-${(i + 1)}'
      adminUsername: VMUsername
      adminPassword: VMPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        name: '${VMName}-${(i + 1)}-OSDISK'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        diskSizeGB: 127
      }
      dataDisks: []
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaces_MigrationServers[i].id
        }
      ]
    }
    licenseType: ((HybridUseBenefit == 'yes') ? 'Windows_Server' : json('null'))
  }
}]

resource customScriptExtension_MigrationServers 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, VMInstances): {
  parent: virtualMachines_MigrationServers[i]
  name: 'CustomScriptExtension'
  location: Location
  tags: {}
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${RepositoryUri}scripts/Add-AzureFileShare.ps1${RepositorySasToken}'
      ]
      timestamp: Timestamp
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File Add-AzureFileShare.ps1 -ShareName ${FileShareName} -StorageAccountName ${StorageAccountName} -StorageKey ${storageAccount.listKeys().keys[0].value} -StorageSuffix ${StorageSuffix} -VMUsername ${VMUsername} -VMPassword ${VMPassword}'
    }
  }
}]
