# sample parameters
$VMParameters = @{
    VMName = 'grafana'
    VMSwitchName = 'nat'
    Username = 'liam'
    PublicKey = 'ssh-ed25519 AAAAZ'
    OriginalVHDXPath = 'D:\ISOs\AlmaLinux-9-GenericCloud-latest.x86_64.vhdx'
    EnableSecureBoot = $true
    Force = $true
}