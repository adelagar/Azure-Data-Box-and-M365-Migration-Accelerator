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
    $ErrorActionPreference = 'Stop'
    
    function Write-Log
    {
        param(
            [parameter(Mandatory)]
            [string]$Message,
            
            [parameter(Mandatory)]
            [string]$Type
        )
        $Path = 'C:\cse.txt'
        if(!(Test-Path -Path $Path))
        {
            New-Item -Path 'C:\' -Name 'cse.txt' | Out-Null
        }
        $Timestamp = Get-Date -Format 'MM/dd/yyyy HH:mm:ss.ff'
        $Entry = '[' + $Timestamp + '] [' + $Type + '] ' + $Message
        $Entry | Out-File -FilePath $Path -Append
    }
    try
    {
        # Save the password so the drive will persist on reboot
        cmd.exe /C "cmdkey /add:`"$Using:StorageAccountName.file.$Using:StorageSuffix`" /user:`"localhost\$Using:StorageAccountName`" /pass:`"$Using:StorageKey`""
        Write-Log -Message "Saved the credential successfully." -Type 'INFO' 
        
        # Mount the drive
        New-PSDrive -Name Z -PSProvider FileSystem -Root "\\$Using:StorageAccountName.file.$Using:StorageSuffix\$Using:ShareName" -Persist
        Write-Log -Message "Mounted the drive successfully." -Type 'INFO' 
    }
    catch {
        Write-Log -Message $_ -Type 'ERROR'
    }
}