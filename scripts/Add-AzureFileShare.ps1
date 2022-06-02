param(

    [Parameter(Mandatory)]
    [String]$ShareName,
    
    [Parameter(Mandatory)]
    [String]$StorageAccountName,
    
    [Parameter(Mandatory)]
    [String]$StorageKey,
    
    [Parameter(Mandatory)]
    [String]$StorageSuffix,
    
    [Parameter(Mandatory)]
    [String]$VMUsername,
    
    [Parameter(Mandatory)]
    [String]$VMPassword
    
)

# Create the credential for mounting the file share under the local admin context
$Password = ConvertTo-SecureString -String $VMPassword -AsPlainText -Force
[pscredential]$Credential = New-Object System.Management.Automation.PSCredential ($VMUsername, $Password)

Invoke-Command -Credential $Credential -ScriptBlock {
    # Save the password so the drive will persist on reboot
    cmd.exe /C "cmdkey /add:`"$Using:StorageAccountName.file.$Using:StorageSuffix`" /user:`"localhost\$Using:StorageAccountName`" /pass:`"$Using:StorageKey`""
        
    # Mount the drive
    New-PSDrive -Name Z -PSProvider FileSystem -Root "\\$Using:StorageAccountName.file.$Using:StorageSuffix\$Using:ShareName" -Persist
}