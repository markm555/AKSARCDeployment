# Script to deploy an AKS Cluster and install a custom location and ARC for Kubernetes
# This will provide you with a working platform capable of hosting all of the ARC services that run on Kubernetes
# Such as ARC Data Controller, ARC SQL MI, ARC Postgres (Citus), ARC Azure ML.  More services are coming to this platform
#
# 06/19/2021 - Created - Mark Moore (markm@microsoft.com) 

Clear-Host
write-host "***********************************************************************************************"
write-host "**                         Installing Azure CLI for Windows                                  **"
write-host "***********************************************************************************************"

$aztest = az
If ($aztest -eq $null)
{
    write-host "Azure CLI not installed installing now"
    Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi'
}
else
{
    write-host "Azure CLI already installed continuing to next step"    
}

write-host "***********************************************************************************************"
write-host "**                         Installing Az Data for Windows                                    **"
write-host "***********************************************************************************************"

$azdatatest = azdata --version
If ($azdatatest -eq $null)
{
    write-host "Azure CLI not installed installing now"
    Invoke-WebRequest -Uri https://aka.ms/azdata-msi -OutFile .\Azdata.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I Azdata.msi'
}
else
{
    write-host "Azure CLI already installed continuing to next step"    
}

write-host "***********************************************************************************************"
write-host "**                      Login to Azure and Select a Subscription                             **"
write-host "***********************************************************************************************"

$textline ="|                                                                                                                       "

$sub = az login
$subs = $sub | ConvertFrom-Json
$i=0
$selection = @(0..500)
$goodselection = "n"

While ( $goodselection -ne "Y" -or $goodselection -ne "y" )
{
    $textline ="|                                                                                                                       "
    write-host "______________________________________________________________________________________________________"
    write-host "|    |           Subscription name                |              Subscription ID          | Status   |"
    write-host "|____|____________________________________________|_______________________________________|__________|"
    Foreach ($sub in $subs)
    {

        $textline = $textline.insert(2,$($i))
        $textline = $textline.insert(5,'|')
        $textline = $textline.insert(7,$($sub.name))
        $textline = $textline.insert(50,'|')
        $textline = $textline.insert(52,$($sub.id))
        $textline = $textline.insert(90,'|')
        $textline = $textline.insert(92,$($sub.state))
        $textline = $textline.insert(101,'|')

        write-host $textline.substring(0,102)

        $selection[$i] = $($sub.id)
        $i=$i+1
        $textline ="|                                                                                                                                                "
    }
    $script = Read-Host -Prompt "Enter the number next to the subscription you would like to host AKS and all components for the demo"

    write-host "You selected this subscription"
    write-host $selection[$script]

    $goodselection = Read-Host -Prompt "Is this correct [Y} Yes, [N} No"
}


az account set --subscription $selection[$script]

write-host "***********************************************************************************************"
write-host "**                   Create a new Resource Group for Arc Demo                                **"
write-host "***********************************************************************************************"

$rg = "ARKAKSdemo"+"-"+(New-Guid).ToString('N').Substring(0,4)
az group create --name $($rg) --location eastus

write-host "***********************************************************************************************"
write-host "**                                  Create the AKS Cluster                                   **"
write-host "***********************************************************************************************"

$cluster = "AKScluster"+"-"+(New-Guid).ToString('N').Substring(0,4)

write-host "*** W A R N I N G *** Creating a 3 node AKS cluster with an approximate cost of 840/mo if left running   ***"
write-host "*** If you choose to proceed, please delete your resource group after the demo to keep cost low.         ***"


    az aks create --resource-group $rg --name $cluster --node-vm-size standard_D8s_v3 --node-count 3 --enable-addons monitoring --generate-ssh-keys

az aks install-cli

az aks get-credentials --resource-group $rg --name $cluster

CMD.EXE /C .azure-kubectl\kubectl get nodes
CMD.EXE /C .azure-kubectl\kubectl get pods -A -o wide

write-host "***********************************************************************************************"
write-host "**                         Creating ARC Data Controller                                      **"
write-host "***********************************************************************************************"
$env:ACCEPT_EULA = "yes"
CMD.EXE /C set ACCEPT_EULA = "yes"
CMD.EXE /C set AZDATA_USERNAME = "demo"
CMD.EXE /C set AZDATA_PASSWORD = "Demopass@word1"

$dcname = "arcdc"+"-"+(New-Guid).ToString('N').Substring(0,4)
$namespace = "arcdc"
$arc_profile = 'azure-arc-aks-default-storage'

azdata arc dc create --connectivity-mode Indirect -n $dcname -ns $namespace -s $selection[$script] -g $script -l eastus -sc default --profile-name $arc_profile

CMD.EXE /C .azure-kubectl\kubectl get pods -A -o wide do -w 

write-host "***********************************************************************************************"
write-host "**                         Creating Postgres CITUS Instance                                  **"
write-host "***********************************************************************************************"

$pgname = "pg"+"-"+(New-Guid).ToString('N').Substring(0,4)
azdata arc postgres server create -n $pgname --workers 2