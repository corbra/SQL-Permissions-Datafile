SET-Location $PSScriptRoot

. "$PSScriptRoot\Functions\Update-SQLRoles.ps1"

Start-Transcript -PATH (".\log\$($MyInvocation.MyCommand.Name)_" + (get-date -format yyyyMMdd_HHmm) + ".log") -UseMinimalHeader

# Import profile and apply permissions
$LiteralPath = "Sample_PermissionsTemplate.psd1"
$PermissionTemplate = Import-PowerShellDataFile -LiteralPath $LiteralPath

# Get instance and role from template
$SQLInstance = $PermissionTemplate.Values.SQLInstance | select-object -Unique
$Roles = $PermissionTemplate.Values.Role  | select-object -Unique

# Get a snapshot of the permission pre-import
Show-Report -SqlInstance $SQLInstance  -Principles $Roles -WriteToCSV  -Folder "C:\Temp\Pre" 

do{
    $ans = Read-Host "Updating $SQLInstance, continue to update sql security? (Y/N)"
    if($ans -eq 'N'){ 
        Stop-Transcript
        Exit 1 
    }
}
until($ans -eq 'Y')

$PermissionTemplate | Update-SQLRoles -confirm:$false | Out-Null

Write-Host "Set Login Mappings $(Get-Date -Format G)" -ForegroundColor Magenta
# Do logins mappings
$Mapping = @{
    "DOMAIN\Testers" = "tester"
    "DOMAIN\Developers" = "developer"
}
Set-LoginMappings -SqlInstance $SQLInstance -Mapping $Mapping -RemoveExisting -MapServerLevel -confirm:$false

Write-Host "Show Reports" -ForegroundColor Magenta
# Show Reports
Show-Report -SqlInstance $SQLInstance  -Principles $Roles
Show-Report -SqlInstance $SQLInstance  -Principles $Mapping.Keys
Show-Report -SqlInstance $SQLInstance  -Principles $Roles -WriteToCSV -Folder "C:\Temp\Post" 

Stop-Transcript
