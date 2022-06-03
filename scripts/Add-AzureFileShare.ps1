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

$Share = "\\$StorageAccountName.file.$StorageSuffix\$ShareName"
$DeleteShare = 'net use z: /delete'
$AddShare = "net use z: $Share $StorageKey /user:Azure\$StorageAccountName"
$Path = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup'
$File = New-Item -Path $Path -Name 'Share.bat' -ItemType 'File' -Force
$DeleteShare | Out-File -FilePath $File.FullName -Append -Force
$AddShare | Out-File -FilePath $File.FullName -Append -Force