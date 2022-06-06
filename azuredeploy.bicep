@maxLength(80)
@minLength(1)
@description('The name of the Azure Bastion Host.')
param BastionInstanceName string

@description('The address prefix for the Azure Bastion subnet. This value must be in CIDR notation (e.g. 10.0.0.0/27) and the network prefix must be /27.')
param BastionSubnetPrefix string = '10.230.1.0/27'

@description('This value determines whether a DNS Server is deployed. The server will be configured with the appropriate conditional forwarder to support the Private Endpoint on Azure Files.  This is only needed if you will integrate your organizations\'s DNS with the solution.')
param DnsServer bool = true

@description('The IP address for the Forwarder on the DNS Server.')
param DnsServerForwarderIPAddresses array = []

@maxLength(15)
@minLength(1)
@description('The name of the Virtual Machine for the DNS server. Due to NETBIOS restrictions in Windows, this value must be 15 characters or shorter.')
param DnsServerName string = ''

@description('The size of the virtual machine for the DNS server.')
param DnsServerSize string = 'Standard_D2s_v4'

@maxLength(63)
@minLength(3)
@description('The name of the file share in Azure Files.')
param FileShareName string

@maxValue(1000)
@minValue(100)
@description('The size in GB of the file share in Azure Files.')
param FileShareSize int = 100

@allowed([
  'yes'
  'no'
])
@description('This value determines whether the virtual machines in this solution should use the Hybrid Use Benefit for Windows Server. https://docs.microsoft.com/en-us/windows-server/get-started/azure-hybrid-benefit')
param HybridUseBenefit string = 'no'

@maxLength(80)
@minLength(1)
@description('The name of the subnet for the jump host virtual machines.')
param JumpHostSubnetName string

@description('The address prefix for the jump host subnet. This value must be in CIDR notation (e.g. 10.0.0.0/24).')
param JumpHostSubnetPrefix string = '10.230.0.0/24'

@maxLength(80)
@minLength(1)
@description('The name of the subnet for the private endpoint on Azure Files.')
param PrivateEndpointSubnetName string

@description('The address prefix for the Private Endpoint subnet. This value must be in CIDR notation (e.g. 10.0.0.0/27) and the network prefix must be /27.')
param PrivateEndpointSubnetPrefix string = '10.230.2.0/27'

@description('The address prefix for the GatewaySubnet subnet. This value must be in CIDR notation (e.g. 10.0.0.0/27) and the network prefix must be /27.')
param GatewaySubnetPrefix string = '10.230.3.0/27'

@secure()
@description('The SAS Token for Azure Blob storage to host a private or custom version of this solution.  The default value of null may be used if deploying from GitHub.')
param RepositorySasToken string = ''

@description('The URL to the repository for the code.  The default value may be used if deploying from GitHub.  However, if you network blocks public internet access or you would like to modify the code then you should host your own copy in a Azure Blobs.')
param RepositoryUri string = 'https://raw.githubusercontent.com/jamasten/Azure-Data-Box-and-M365-Migration-Accelerator/main/'

@maxLength(24)
@minLength(3)
@description('The name of the storage account to store you migration data. The value must be 24 characters or less. Special characters are not allowed. The value must be in lowercase.')
param StorageAccountName string

@description('The timestamp is used to rerun VM extensions when the template needs to be redeployed due to an error or update.')
param Timestamp string = utcNow()

@maxLength(64)
@minLength(2)
@description('The name of the virtual network.')
param VirtualNetworkName string

@description('The address prefix for the virtual network. This value must be in CIDR notation (e.g. 10.0.0.0/21).')
param VirtualNetworkAddressPrefix string = '10.230.0.0/21'


@allowed([
  'Standard_DS2_v2' // should this be changed to a v4 size? // add sizes that use accelerated networking
  'Standard_DS3_v2' // should this be changed to a v4 size?
  'Standard_D4as_v4'
])
@description('The size of the virtual machines migrating your data.')
param VMSize string = 'Standard_DS2_v2'

@maxLength(14)
@minLength(1)
@description('The name prefix for the virtual machines migrating your data. Due to NETBIOS restrictions in Windows, this value must be 14 characters or shorter. One character is reserved for a number that will be appended to the end of the name.')
param VMName string

@maxValue(9)
@minValue(1)
@description('The number of virtual machines needed to expedite your data migration.')
param VMInstances int = 2

@maxLength(20)
@minLength(1)
@description('The username for the local administrator account.')
param VMUsername string

@secure()
@description('The password for the local administrator account.')
param VMPassword string

var BastionPublicIpAddressName = '${BastionInstanceName}-pip'
var DnsServerNetworkAddress = split(JumpHostSubnetPrefix, '/')[0]
var DnsServerOctet0 = split(DnsServerNetworkAddress, '.')[0]
var DnsServerOctet1 = split(DnsServerNetworkAddress, '.')[1]
var DnsServerOctet2 = split(DnsServerNetworkAddress, '.')[2]
var DnsServerOctet3 = split(DnsServerNetworkAddress, '.')[3]
var DnsServerIpNumber = DnsServerOctet3 == '0' ? 4 : int(DnsServerOctet3) + 4
var DnsServerIpAddress = '${DnsServerOctet0}.${DnsServerOctet1}.${DnsServerOctet2}.${DnsServerIpNumber}'
var Location = resourceGroup().location
var MicrosoftDnsServer = '168.63.129.16'
var PrivateDnsZoneName = 'privatelink.file.${StorageSuffix}'
var PrivateEndpointName = '${StorageAccountName}-pe'
var StorageSuffix = environment().suffixes.storage

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2018-08-01' = {
  name: '${JumpHostSubnetName}-nsg'
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
      dnsServers: DnsServer ? [
        DnsServerIpAddress
        MicrosoftDnsServer
      ] : [
        MicrosoftDnsServer
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
  name: '${DnsServerName}-nic'
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
    enableAcceleratedNetworking: false
    enableIPForwarding: false
  }
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
        name: '${DnsServerName}-osdisk'
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
/* 
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
      modulesUrl: '${RepositoryUri}configurations/dnsForwarders.zip${RepositorySasToken}'
      configurationFunction: 'dnsForwarders.ps1\\dnsForwarders'
      configurationArguments: {
        ActionAfterReboot: 'ContinueConfiguration'
        ConfigurationMode: 'ApplyandAutoCorrect'
        RebootNodeIfNeeded: true
      }
      properties: [
        {
          Name: 'ForwarderIPAddresses'
          Value: DnsServerForwarderIPAddresses
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

resource networkInterfaces_MigrationServers 'Microsoft.Network/networkInterfaces@2019-11-01' = [for i in range(1, VMInstances): {
  name: '${VMName}${i}-nic'
  location: Location
  tags: {
    displayName: '${VMName}${i}-nic'
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
  dependsOn: [
    dscExtension_DnsServer
  ]
}]

resource virtualMachines_MigrationServers 'Microsoft.Compute/virtualMachines@2019-07-01' = [for i in range(1, VMInstances): {
  name: '${VMName}${i}'
  location: Location
  tags: {
    displayName: '${VMName}${i}'
  }
  properties: {
    hardwareProfile: {
      vmSize: VMSize
    }
    osProfile: {
      computerName: '${VMName}${i}'
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
        name: '${VMName}${i}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: 127
      }
      dataDisks: []
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaces_MigrationServers[(i-1)].id
        }
      ]
    }
    licenseType: ((HybridUseBenefit == 'yes') ? 'Windows_Server' : json('null'))
  }
}]

resource customScriptExtension_MigrationServers 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(1, VMInstances): {
  parent: virtualMachines_MigrationServers[(i-1)]
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
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File Add-AzureFileShare.ps1 -ShareName ${FileShareName} -StorageAccountName ${StorageAccountName} -StorageKey ${storageAccount.listKeys().keys[0].value} -StorageSuffix ${StorageSuffix}'
    }
  }
}]
 */

 output forwarderIpAddresses array = DnsServerForwarderIPAddresses
