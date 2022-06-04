param(

    [Parameter(Mandatory)]
    [String]$ShareName,
    
    [Parameter(Mandatory)]
    [String]$StorageAccountName,
    
    [Parameter(Mandatory)]
    [String]$StorageKey,
    
    [Parameter(Mandatory)]
    [String]$StorageSuffix
    
)

$ErrorActionPreference = 'Stop'

$FileShare = '\\' + $StorageAccountName + '.file.' + $StorageSuffix + '\' + $ShareName
$Username = 'Azure\' + $StorageAccountName
$Password = ConvertTo-SecureString -String "$($StorageKey)" -AsPlainText -Force
[pscredential]$Credential = New-Object System.Management.Automation.PSCredential ($Username, $Password)
New-SmbGlobalMapping -RemotePath $FileShare -Credential $Credential -LocalPath 'Z:'
