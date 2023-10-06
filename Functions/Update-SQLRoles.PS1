. "$PSScriptRoot\Functions.ps1"

Function Update-SQLRoles{
    <#
.SYNOPSIS
    .
.DESCRIPTION

.PARAMETER PermissionTemplate
The datafile hashtable.
    
.OUTPUTS
    TODO
.NOTES
    Tags: SQLServer
    Author: Cormac Bracken
    Website:
    Copyright: icensed under MIT
    License: MIT https://opensource.org/licenses/MIT
    Prerequisits: DBATools https://dbatools.io

.EXAMPLE    
    $LiteralPath = "Sample_PermissionsTemplate.psd1"
    $PermissionTemplate = Import-PowerShellDataFile -LiteralPath $LiteralPath
    $PermissionTemplate | Update-SQLRoles -confirm:$false | Out-Null
    
    #>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium')]
param (
    [Parameter(Mandatory=$true,ValueFromPipeline = $true)]
    [hashtable]$PermissionTemplate
)

    $Progress = @{
        Activity = 'Updating'
        CurrentOperation = "Updating"
        Status = 'Progress'
        PercentComplete = 0
    }
    $u = 0

    foreach ( $_Profile in $PermissionTemplate.GetEnumerator() )
    {
        # write progress bar
        $u++
        $Progress.Status = "Processing $($_Profile.name)"
        #$Progress.Status = "$u of $($PermissionTemplate.count)"
        $Progress.PercentComplete = ($u / $PermissionTemplate.count) * 100
        Write-Progress @Progress
        Write-Host "Processing $($_Profile.name)" -ForegroundColor green

        if ( $_Profile.value.SQLInstance.count -lt 1 ){
            Write-Error "No SQL Instances declared for profile $($_Profile.Name)"
            continue;
        }

        if($_Profile.value.RemoveExisting){
            if ($PSCmdlet.ShouldProcess($_Profile.value.SQLInstance,"Remove Existing Roles")){
                Write-Verbose "$(Get-Date -Format "dddd, dd MMMM yyyy, HH:mm K") Removing $($_Profile.value.Role) from $($_Profile.value.SQLInstance)" 
                Remove-DbaDbRole -SqlInstance $_Profile.value.SQLInstance -Role $_Profile.value.Role -IncludeSystemDbs -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference | out-null
                Remove-DBAServerRole -SqlInstance $_Profile.value.SQLInstance -ServerRole $_Profile.value.Role -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference | out-null
            }
        }


        
        <# SET SERVER LEVEL PRIVILEGES #>
        
        
        if ($_Profile.value.ServerProfile.Permissions.count -gt 0){
            New-DbaServerRole -SqlInstance $_Profile.value.SQLInstance -ServerRole $_Profile.value.Role -Owner sa -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference | out-null

            foreach ($_SqlInstance in $_Profile.value.SQLInstance){


                if ($PSCmdlet.ShouldProcess($_SqlInstance,"SET SERVER LEVEL PERMISSIONS")){
                    foreach ($_Permission in $_Profile.value.ServerProfile.Permissions){

                        $_Profile.value.Role | ForEach-Object -Process {
                        $Query = "$_Permission TO [$_]"
                        Write-Verbose "Set Server Level Permissions: $_SqlInstance Applying $Query" 
                        Invoke-DbaQuery -SqlInstance $_SqlInstance -Query $Query 
                        }
                    }
                }
            }
        }

        if ($_Profile.value.ServerProfile.Roles.count -gt 0){
            Add-DbaServerRoleMember -SqlInstance $_Profile.value.SQLInstance -ServerRole $_Profile.value.ServerProfile.Roles -Login $_Profile.value.Role -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference | out-null
        }

        <# SET DATABASE LEVEL PRIVILEGES #>
        foreach ($_Database_Profile in $_Profile.value.DatabaseProfiles){
            $Parameters  = @{
                SqlInstance = $_Profile.value.SQLInstance
                Role= $_Profile.value.Role
                Permissions = $_Database_Profile.Permissions
                IncludeDatabase = $_Database_Profile.Include
                ExcludeDatabase = $_Database_Profile.Exclude
                ExcludeSystem = $_Database_Profile.ExcludeSystem
                RoleMembership = $_Database_Profile.Roles
            }

            Set-DBRolePrivilege @Parameters -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference | out-null
        }
    }

    Write-Progress @Progress -Completed
    Write-Host "Update Complete $(Get-Date -Format G)" -ForegroundColor Magenta

    Write-Output $PermissionTemplate
}


