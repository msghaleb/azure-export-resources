# Login Function (needed only locally)
Function Login
{
    $needLogin = $true

    # checking the AzureRM connection if login is needed
    Try 
    {
        $content = Get-AzureRmContext
        if ($content) 
        {
            $needLogin = ([string]::IsNullOrEmpty($content.Account))
        } 
    } 
    Catch 
    {
        if ($_ -like "*Login-AzureRmAccount to login*") 
        {   
            $needLogin = $true
        } 
        else 
        {
            Write-Host "You are already logged in to Azure, that's good."
            throw
        }
    }

    if ($needLogin)
    {
        Write-Host "You need to login to Azure"
        Login-AzureRmAccount
    }

    # Checking the Azure AD connection and if login is needed
    #try { 
    #    Get-AzureADTenantDetail 
    #}
    #catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] { 
    #    Write-Host "You're not connected to the Azure AD."
    #    Connect-AzureAD
    #}

}

#checking if you are on Azure Shell
if ( (Get-Module | where-Object {$_.Name -like "AzureAD.Standard.Preview"}).Count ) {
    Write-Host "You are on Azure Shell"
}
else {
    Write-Host "You are working locally"
    # checking if you have the needed modules installed
    # check for and install the AzureAD if needed
    Import-Module AzureAD -ErrorAction SilentlyContinue | Out-Null 
    If ( !(Get-Module | where-Object {$_.Name -like "AzureAD"}).Count ) { Install-Module AzureAD -scope CurrentUser }

    # check for and install the AzureRM if needed
    Import-Module AzureRm.Resources -ErrorAction SilentlyContinue | Out-Null 
    If ( !(Get-Module | where-Object {$_.Name -like "AzureRM.Resources"}).Count ) { Install-Module AzureRM -scope CurrentUser}

    # Loggin in to Azure (if needed)
    Login
}

#Setting the current date and time for folder creating
$currentDate = $((Get-Date).ToString('yyyy-MM-dd--hh-mm'))

#creating a sub folder for the output.
Write-Host "Creating a Sub Folder for the output files"
Try {
    New-Item -ItemType Directory -Path ".\$currentDate"  | Out-Null
    # setting the path
    $outputPath = ".\$currentDate"
} 
Catch {
    Write-Output "Failed to create the output folder, please check your permissions"
}

#creating a sub folder for the subscriptions one by one.
Write-Host "Creating a Sub Folder for the subscriptions one by one output files"
Try {
    New-Item -ItemType Directory -Path ".\$currentDate\subscriptions_one_by_one"  | Out-Null
    # setting the path
    $subsPath = ".\$currentDate\subscriptions_one_by_one"
} 
Catch {
    Write-Output "Failed to create the groups sub folder, please check your permissions"
}

# Export resrouces for all subscriptions the user has access to

    $AzureResources = @()
    #Loop through each Azure subscription user has access to
    Foreach ($sub in Get-AzureRmSubscription) {
        $SubName = $sub.Name
        if ($sub.Name -ne "Access to Azure Active Directory") { # The Access to Azure Active Directory subscriptions is out of scope
            Set-AzureRmContext -SubscriptionId $sub.id
            Write-Host "Exporting resrouces for $subname"
            Write-Host ""
            Try {
                #############################################################################################################################
                #### Modify this line to filter what you want in your results.
                #############################################################################################################################
                $Current = Get-AzureRMResource | Where-Object {$_.ResourceType -eq "Microsoft.ContainerService/managedClusters"} | Select-Object -Property @{Name = 'SubscriptionName'; Expression = {$sub.name}}, @{Name = 'SubscriptionID'; Expression = {$sub.id}}, Name, ResourceGroupName, ResourceType, Location
                #$Current = Get-AzureRMResource | Select-Object -Property @{Name = 'SubscriptionName'; Expression = {$sub.name}}, @{Name = 'SubscriptionID'; Expression = {$sub.id}}, Name, ResourceGroupName, ResourceType, Location
                $AzureResources += $Current
            } 
            Catch {
                Write-Output "Failed to collect resources for $subname"
            }
                       
            #Export the subscription resrouces to a CSV file labeled by the subscription name
            $csvAzureResources = $SubName.replace("/","---")
            $Current | Export-CSV "$subsPath\Subscription--$csvAzureResources-resrouces.csv" -Delimiter ';' -force -notypeinformation
        }
    }

    #Export All resrouces in to a single CSV file
    $AzureResources | Export-CSV "$outputPath\Azure--All-Resources.csv" -Delimiter ';' -force -notypeinformation

    # HTML report
    $a = "<style>"
    $a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;font-family:arial}"
    $a = $a + "TH{border-width: 1px;padding: 5px;border-style: solid;border-color: black;}"
    $a = $a + "TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black;}"
    $a = $a + "</style>"
    $AzureResources | ConvertTo-Html -Head $a| Out-file "$outputPath\AllAzureResources.html"