v@{
    <#
        PermissionsTemplate.psd1
        - Version: 1.0.0
        - Last Modified: 03 August 2023
    #>
    
    TESTERS = @{
        SQLInstance = @("SQLSERVERTST001","SQLSERVERTST002") # Target SQL Instance
        Role = @("Tester") # Apply permissions to theses Roles
        RemoveExisting = $true # Remove all Server and Database level Roles targeted prior to applying profiles?

        <# Assign Server level permissions and roles here #>
        ServerProfile = @{ 
            Permissions = @("GRANT CONNECT ANY DATABASE","GRANT SELECT ALL USER SECURABLES","GRANT VIEW ANY DEFINITION")    
            Roles = @()
        }

        <# Assign Database level permissions and roles here - multuple database profiles are allowed #>
        DatabaseProfiles = @(
             @{
                Include = $null # Target Databases, $null will default to all databases
                ExcludeSystem = $true # Include master, msdb, model and tempdb ?
                Exclude = @("sysDBA","ReportServer","ReportServerTempDB","SSISDB") # Ignore these database
                Permissions = @("GRANT SELECT","GRANT UPDATE","GRANT DELETE","GRANT INSERT","GRANT EXECUTE") # Add these permissions to the role
                Roles = @() # Add the role to these roles
            }
            @{ 
                Include = @("msdb")
                Roles = @("SQLAgentReaderRole") 
            }
        )
    }
    DEVELOPERS = @{
        SQLInstance = @("SQLSERVERDEV001","SQLSERVERDEV002") # Target SQL Instance
        Role = @("developer","analysts")
        RemoveExisting = $true # Remove all Server and Database level Roles targeted prior to applying profiles. 

        ServerProfile = @{
            Permissions = @("GRANT ALTER TRACE","GRANT ALTER ANY CONNECTION","GRANT CREATE ANY DATABASE","GRANT CONNECT ANY DATABASE","GRANT SELECT ALL USER SECURABLES","GRANT VIEW ANY DATABASE","GRANT VIEW ANY DEFINITION","GRANT VIEW SERVER STATE")
            Roles = @()
        }
        DatabaseProfiles = @(
             @{
                Include = $null 
                ExcludeSystem = $true
                Exclude = @("sysDBA","ReportServer","ReportServerTempDB","SSISDB") 
                Roles = @("db_reader","db_execute")
            }
            @{
                Include = @("SSISDB")
                Roles = @("ssis_admin") 
            }
            @{
                Include = @("msdb")
                Roles = @("SQLAgentOperatorRole","db_ssisadmin") 
            }
        )
    }
}