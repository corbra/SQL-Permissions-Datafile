## Getting Started
    
Powershell Script to implement a simple SQL access strategy using the [dbatools](https://dbatools.io/download/) module. 

Access is configured declaratively through a powershell [psd1 data file](Sample_PermissionsTemplate.psd1) . The file contains hashtable profiles. Each profile can be setup to configure:
- Target SQl Instances and databases
- New Server level roles with
    - Server Level Permissions
    - Server level role membership
- New Database level roles with
    - database level permissions 
    - Database level role membership

The RemoveExisting property is used to remove/clean existing roles targeted in the script. 
Once created, the function Set-LoginMappings can be used to create a simple mapping of logins/users to roles.
    
- Prerequisite
    - [dbatools](https://dbatools.io/download/) 
        - Install-Module dbatools -Scope CurrentUse

- Sample PowerShell data file Template
    - [Template](Sample_PermissionsTemplate.psd1) 
    - Contains a hash table of keys and values specifiying the permissions to apply

- Sample execution script 
    - [execution script](Start-Import.ps1) 


## Usage scenarios
