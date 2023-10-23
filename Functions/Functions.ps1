Function Select-Databases{
    <#
.SYNOPSIS
    TODO
.DESCRIPTION
    TODO
.PARAMETER Database
    
.PARAMETER ExcludeDatabase

.PARAMETER IncludeDatabase
    
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
    Select-Databases -Database  -ExcludeDatabase -IncludeDatabase


    
    #>
[CmdletBinding(ConfirmImpact='Low')]
param (
    [Parameter(Mandatory=$true)]
    [string[]]$Database,
    [string[]]$ExcludeDatabase,
    [string[]]$IncludeDatabase
)

    if($ExcludeDatabase.count -gt 0){
        if($IncludeDatabase.count -gt 0){
            Write-Error 'Both IncludeDatabase and ExcludeDatabase should not be set' -ErrorAction Stop
        }
        $SelectedUserDB = $AllUserDB | where-object {$ExcludeDatabase -notcontains $_.name}
    }
    elseif ($IncludeDatabase.count -gt 0){
        $SelectedUserDB = $AllUserDB | where-object {$IncludeDatabase -contains $_.name}

        $MissingDB =  $IncludeDatabase | where-object { $SelectedUserDB.name -notcontains $_}
        if ($MissingDB.count) {
            Write-Warning "Database Not Found $MissingDB"
        }
    }
    else{
        $SelectedUserDB = $AllUserDB
    }

    return  $SelectedUserDB
}


Function Set-DBRolePrivilege{
        <#
    .SYNOPSIS
        Creates a SQL Role with privileges.
    .DESCRIPTION
    .PARAMETER SqlInstance
    .PARAMETER Role
    .PARAMETER Permissions
    .PARAMETER RoleMembership
    .PARAMETER ExcludeDatabase
    .PARAMETER IncludeDatabase
    .PARAMETER ExcludeSystem
        
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

        
        #>
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium')]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [Parameter(Mandatory=$true)]
        [string[]]$Role,
        [string[]]$Permissions,
        [string[]]$RoleMembership,
        [string[]]$ExcludeDatabase,
        [string[]]$IncludeDatabase,
        [switch]$ExcludeSystem
    )

    if (($Permissions.count + $RoleMembership.count) -gt 0)  {
       
        foreach ($_SqlInstance in $SqlInstance ){
 
            <# Determine which database(s) should be set #>
            $AllUserDB = Get-DbaDatabase -SqlInstance $_SqlInstance -ExcludeSystem:($ExcludeSystem) -Access ReadWrite -OnlyAccessible
            $SelectedUserDB = Select-Databases -Database $AllUserDB -ExcludeDatabase $ExcludeDatabase -IncludeDatabase $IncludeDatabase

            if($SelectedUserDB.count -gt 0){

                New-DbaDbRole -SqlInstance $_SqlInstance -Database $SelectedUserDB.name -Role $Role  -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference | Out-Null

                if($Permissions.count -gt 0){
                    
                    if ($PSCmdlet.ShouldProcess($_SqlInstance,"SET DATABASE LEVEL PERMISSIONS")){                    
                        $Role | ForEach-Object -Process {
                            foreach ($_Permission in $Permissions){
                                $Query = "$_Permission  TO [$_]"
                                Write-Verbose "Executing: $Query on $_SqlInstance $($SelectedUserDB.name)"
                                $SelectedUserDB | Invoke-DbaQuery -Query $Query 
                            }
                        }
                    }
                }

                if($RoleMembership.count -gt 0){
                    if ($PSCmdlet.ShouldProcess($_SqlInstance,"SET DATABASE LEVEL ROLE MEMBERSHIP")){ 
                        foreach($_RoleMembership in $RoleMembership)
                        {
                            foreach($_Role in $Role){
                                $Query = "ALTER ROLE [$_RoleMembership] ADD MEMBER [$_Role]"
                                Write-Verbose "Executing: $Query on $_SqlInstance $($SelectedUserDB.name)"
                                $SelectedUserDB | Invoke-DbaQuery -Query $Query
                            }
                        }
                    }
                }
            }
            else{
                Write-host "New-RolePermission: No databases selected for sqlinstance $_SqlInstance"
            }
        }
    }
}


Function Set-LoginMappings{
    <#
.SYNOPSIS
    Create and mappings logins to roles
.DESCRIPTION
    Create and mappings logins to roles
.PARAMETER SqlInstance
.PARAMETER Mapping
    Hashtable Login -> Role mapping.   
.PARAMETER MapServerLevel
    Switch.  If the role exists at server level, add the login.
.PARAMETER RemoveExisting
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
    
    $Mapping = @{
        "DOMAIN\Analysts" = "Analyst"
        "DOMAIN\Developers" = "Developer"

    }
    Set-Login -SqlInstance SQLINSTANCE001 -Mapping $Mapping
    #>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium')]
param (
    [parameter(Mandatory, ValueFromPipeline)]
    [DbaInstanceParameter[]]$SqlInstance,
    [Parameter(Mandatory=$true)]
    [hashtable]$Mapping,
    [switch]$MapServerLevel,
    [switch]$RemoveExisting
)

    if($RemoveExisting){
        $SqlInstance | ForEach-Object {
            Stop-DbaProcess -SqlInstance $_ -Login $Mapping.Keys -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference
        }
        Remove-DbaDbUser -SqlInstance $SqlInstance -User $Mapping.Keys -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference  | out-null
        Remove-DbaLogin -SqlInstance $SqlInstance -Login $Mapping.Keys -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference  | out-null
    }

    foreach ($_SqlInstance in $SqlInstance ){

        foreach($_Mapping in  $Mapping.GetEnumerator()){
            # Find all Databases with the role
            $Roles_ = Get-DbaDbRole -SqlInstance $_SqlInstance -Role $_Mapping.Value 
            $Database_ =  $Roles_.Database | Get-Unique

            New-DbaLogin -SqlInstance $_SqlInstance -Login  $_Mapping.Name -PasswordPolicyEnforced -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference | out-null

            if($Database_.count -gt 0){
                New-DatabaseUser -SqlInstance $_SqlInstance -Database  $Database_ -Login $_Mapping.Name -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference  | out-null
                Add-DbaDbRoleMember -SqlInstance $_SqlInstance -Database  $Database_ -Role $_Mapping.Value -User $_Mapping.Name -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference  | out-null
            }

            if($MapServerLevel){
                Add-DbaServerRoleMember -SqlInstance  $_SqlInstance -ServerRole $_Mapping.Value -Login $_Mapping.Name -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference | out-null
            }
        }
    }
}


Function Show-Report{
    <#
.SYNOPSIS
    Display permissions report 
.DESCRIPTION
.PARAMETER InventoryPath
    Path to inventory file
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
    Show-Report -SqlInstance SQLINSTANCE001 -Principles ("tester","analyst")
.EXAMPLE
    Show-Report -SqlInstance SQLINSTANCE001 -Principles ("tester","analyst") -WriteToCSV -Folder "C:\temp"
 
    #>
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$SqlInstance,
        [Parameter(Mandatory=$true)]
        [string[]]$Principles,
        [switch]$WriteToCSV,
        [string]$Folder = ""
    )

    $TSQLServerRoles =
    "
    SELECT @@ServerName As ServerName
        , memberserverprincipal.name AS member_principal_name
        ,roles.name AS server_role_name
        , roles.type_desc AS role_type_desc
        , roles.is_fixed_role AS role_is_fixed_role
        
        , memberserverprincipal.type_desc AS member_principal_type_desc
        , memberserverprincipal.is_fixed_role AS member_is_fixed_role
        , N'ALTER SERVER ROLE ' + QUOTENAME(roles.name) + N' ADD MEMBER ' + QUOTENAME(memberserverprincipal.name) AS AddRoleMembersStatement
    FROM sys.server_principals AS roles
    INNER JOIN sys.server_role_members
        ON sys.server_role_members.role_principal_id = roles.principal_id
    INNER JOIN sys.server_principals AS memberserverprincipal
        ON memberserverprincipal.principal_id = sys.server_role_members.member_principal_id
    WHERE roles.type = N'R'"

    $TSQLServerPermission =
    "SELECT @@ServerName As ServerName
            , granteeserverprincipal.name AS grantee_principal_name
            , sys.server_permissions.permission_name
            , sys.server_permissions.state_desc
    
            , grantorserverprinicipal.name AS grantor_name
            , CASE 
                WHEN sys.server_permissions.state = N'W'
                    THEN N'GRANT'
                ELSE sys.server_permissions.state_desc
                END + N' ' + sys.server_permissions.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS + N' TO ' + QUOTENAME(granteeserverprincipal.name) AS permissionstatement
    FROM sys.server_principals AS granteeserverprincipal
    INNER JOIN sys.server_permissions
        ON sys.server_permissions.grantee_principal_id = granteeserverprincipal.principal_id
    INNER JOIN sys.server_principals AS grantorserverprinicipal
        ON grantorserverprinicipal.principal_id = sys.server_permissions.grantor_principal_id"

    $TSQLDatabaseRoles =
    "SELECT @@ServerName as ServerName, DB_NAME() AS DatabaseName
        , memberdatabaseprincipal.name AS member_name 
        , roles.name AS role_name
        , roles.is_fixed_role AS role_is_fixed_role
        , memberdatabaseprincipal.type AS member_type
        , N'ALTER ROLE ' + QUOTENAME(roles.name) + N' ADD MEMBER ' + QUOTENAME(memberdatabaseprincipal.name) AS AddRoleMembersStatement
    FROM sys.database_principals AS roles
    INNER JOIN sys.database_role_members
        ON sys.database_role_members.role_principal_id = roles.principal_id
    INNER JOIN sys.database_principals AS memberdatabaseprincipal
        ON memberdatabaseprincipal.principal_id = sys.database_role_members.member_principal_id
    LEFT OUTER JOIN sys.server_principals AS memberserverprincipal
        ON memberserverprincipal.sid = memberdatabaseprincipal.sid"


    $TSQLDatabasePermission =
    "SELECT @@ServerName As ServerName, DB_NAME() AS DatabaseName
            ,DatabasePrincipals.name AS PrincipalName
            ,DatabasePrincipals.type_desc AS PrincipalType
            ,DatabasePermissions.permission_name AS Permission
            ,DatabasePermissions.state_desc AS StateDescription
            ,SCHEMA_NAME(SO.schema_id) AS SchemaName
            ,SO.Name AS ObjectName
            ,SO.type_desc AS ObjectType
        FROM sys.database_permissions DatabasePermissions LEFT JOIN sys.objects SO
        ON DatabasePermissions.major_id = so.object_id LEFT JOIN sys.database_principals DatabasePrincipals
        ON DatabasePermissions.grantee_principal_id = DatabasePrincipals.principal_id LEFT JOIN sys.database_principals DatabasePrincipals2
        ON DatabasePermissions.grantor_principal_id = DatabasePrincipals2.principal_id"


    foreach($_Principle in $Principles){
        
        if ($_Principle -eq $Principles[0])#first
        { 
            $TSQLServerRoles += " and memberserverprincipal.name = '$_Principle'"
            $TSQLServerPermission += " where granteeserverprincipal.name = '$_Principle'"
            $TSQLDatabaseRoles += " where memberdatabaseprincipal.name = '$_Principle'"
            $TSQLDatabasePermission += " where DatabasePrincipals.name = '$_Principle'"
        }
        elseif ($_Principle -eq $Principles[-1])#last
            {  
                $TSQLServerRoles += " OR memberserverprincipal.name = '$_Principle'"
                $TSQLServerPermission += " OR granteeserverprincipal.name = '$_Principle'"
                $TSQLDatabaseRoles += "  OR memberdatabaseprincipal.name = '$_Principle'"
                $TSQLDatabasePermission += " OR DatabasePrincipals.name = '$_Principle'"
            }
        else{
            $TSQLServerRoles += " OR memberserverprincipal.name = '$_Principle'"
            $TSQLServerPermission += " OR granteeserverprincipal.name = '$_Principle'"
            $TSQLDatabaseRoles += " OR memberdatabaseprincipal.name = '$_Principle'"
            $TSQLDatabasePermission += " OR DatabasePrincipals.name = '$_Principle'"
        }
    }
    $TSQLServerRoles += " ORDER BY server_role_name, member_principal_name"
    $TSQLServerPermission += " ORDER BY granteeserverprincipal.name, sys.server_permissions.permission_name"
    $TSQLDatabaseRoles += " ORDER BY role_name, member_name"
    $TSQLDatabasePermission += " order by DatabasePrincipals.name"

    $Database = Get-DbaDatabase -SqlInstance $SqlInstance

    if($WriteToCSV)
    {
        $Time = (get-date -format yyyyMMdd_HHmm)
    
        Write-Host "Write permissions report to csv, folder: $Folder, time: $Time" -ForegroundColor Magenta
        
        $outfile = "$Folder\DatabasePermissionsRefresh_" + $Time  + ".csv"
        Write-Verbose "Exporting Database Permissions to $outfile"
        $Database  | Invoke-DbaQuery -Query $TSQLDatabasePermission |  Export-Csv -Path $outfile -NoTypeInformation
        
        $outfile = "$Folder\DatabaseRolesRefresh_" + $Time  + ".csv"
        Write-Verbose "Exporting Database Role Permissions to $outfile"
        $Database  | Invoke-DbaQuery -Query $TSQLDatabaseRoles |  Export-Csv -Path $outfile -NoTypeInformation 
        
        $outfile = "$Folder\ServerPermissionsRefresh_" + $Time  + ".csv"
        Write-Verbose "Exporting Server Permissions to $outfile"
        Invoke-DbaQuery -SqlInstance $SqlInstance -Query $TSQLServerPermission |  Export-Csv -Path $outfile -NoTypeInformation 
        
        $outfile = "$Folder\ServerRolesRefresh_" + $Time  + ".csv"
        Write-Verbose "Exporting Server Roles to $outfile"
        Invoke-DbaQuery -SqlInstance $SqlInstance -Query $TSQLServerRoles |  Export-Csv -Path $outfile -NoTypeInformation 
    }
    else {
        
        Write-Host "Database Permission Report" -ForegroundColor Magenta
        $Database  | Invoke-DbaQuery -Query $TSQLDatabasePermission   | Group-Object ServerName,PrincipalName,Permission -NoElement  | format-table -AutoSize
        Write-Host "Database Roles Report" -ForegroundColor Magenta
        $Database  | Invoke-DbaQuery -Query $TSQLDatabaseRoles    | Group-Object ServerName,member_name,role_name -NoElement  | format-table -AutoSize
        Write-Host "ServerPermission Report" -ForegroundColor Magenta
        Invoke-DbaQuery -SqlInstance $SqlInstance -Query $TSQLServerPermission   | Group-Object ServerName,grantee_principal_name,permission_name -NoElement  | format-table -AutoSize
        Write-Host "Server Roles Report" -ForegroundColor Magenta
        Invoke-DbaQuery -SqlInstance $SqlInstance -Query $TSQLServerRoles  | Group-Object ServerName,member_principal_name,server_role_name -NoElement | format-table -AutoSize
    }
}

