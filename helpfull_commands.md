# Role and permissions help
## Check ownership
```
$Instance = "SQLSERVERTST001"
$Login = "DOMAIN\Testers"
```

# Get Database where user is owner
```
$Results = Invoke-DbaQuery -SqlInstance $Instance -Query 'SELECT name, suser_sname( owner_sid ) AS DBOwnerName FROM master. sys. databases;'
$Databases = $Results |Where-Object {$_.DBOwnerName -eq $Login} | select-object name
```


# Helpful Queries


## List fixed Server Level

```
$Server = "SQLSERVERTST001"

Invoke-DbaQuery -SqlInstance $Server -Query "SELECT * FROM sys.fn_builtin_permissions('SERVER') ORDER BY permission_name;" | select-object permission_name,covering_permission_name
Invoke-DbaQuery -SqlInstance $Server -Query "sp_helpsrvrole;" 
```

## List fixed Object Level
```
Invoke-DbaQuery -SqlInstance $Server -Query "sp_helpdbfixedrole ;" 
Invoke-DbaQuery -SqlInstance $Server -Query "SELECT * FROM fn_builtin_permissions('DATABASE');" | select-object permission_name ,covering_permission_name,parent_covering_permission_name | Format-Table 
```

# Cleanup Roles
```
$SqlInstance = @("SQLSERVERTST001","SQLSERVERTST001\INST1")
$Roles = @("tester","developer")

Remove-DbaDbRole -SqlInstance $SqlInstance -Role $Roles -IncludeSystemDbs -whatif
Remove-DBAServerRole -SqlInstance $SqlInstance  -ServerRole $Roles -whatif
Get-DbaDbRole -SqlInstance $SqlInstance -Role $Roles | Format-Table -Autosize
```
## Edge case 
'''
where drop fails due to ssisdb [ddl_cleanup_object_permissions] trigger check
Invoke-DbaQuery -SqlInstance $SqlInstance -Database msdb -Query  "ALTER ROLE [ssis_admin] DROP MEMBER [$($Roles)]"
Get-DbaDbRole -SqlInstance $SqlInstance -Role $Roles | Format-Table -Autosize
'''

# Cleanup Logins
```
$Login = @(
"DOMAIN\Testers",
"DOMAIN\Analysts",
"DOMAIN\Developers"
)

$SqlInstance | ForEach-Object {
    Stop-DbaProcess -SqlInstance $_ -Login $login -Whatif
}

Remove-DbaDbUser -SqlInstance $SqlInstance -User $login -Whatif
Remove-DbaLogin -SqlInstance $SqlInstance -Login $login -Whatif
Get-DbaDbRoleMember -SqlInstance $SqlInstance -Role $Roles | Format-table -Autosize

#An alternative - Only remove the database users - Does not kill sessions.
Remove-DbaDbUser -SqlInstance $SqlInstance -User $Login -whatif #-Confirm:$false
```

# Display the results
```
#Get-DbaUserPermission -SqlInstance $SqlInstance | where-object {($_.grantee -eq $Roles -and $_.granteeType -eq "DATABASE_ROLE") -or ($_.Member -eq $Roles -and $_.Type -eq "DB ROLE MEMBERS") } | Select-Object SqlInstance,Object,Grantee,State,Permission,Member,RoleSecurableClass | Format-Table -AutoSize
```
