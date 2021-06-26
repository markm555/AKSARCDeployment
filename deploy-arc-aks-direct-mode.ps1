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

$script = Read-Host -Prompt "Press Enter to continue:"

write-host "***********************************************************************************************"
write-host "**                                   Installing Helm                                         **"
write-host "**  Per Marina Levin I have added the following line to resolve issues install choco         **"
write-hsot "**   if (!(Test-Path -Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }      **"
write-host "***********************************************************************************************"

$helmtest = helm

if ($helmtest -eq $null)
{

    if (!(Test-Path -Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force } # Thanks Marina

    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    choco install kubernetes-helm
}
else 
{
    Write-Host "Helm already installed"
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

$script = Read-Host -Prompt "Press Enter to continue:"

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
write-host "**                          Installing Kubernetes Extensions                                 **"
write-host "***********************************************************************************************"

try 
{
    az extension add --name connectedk8s 
    az extension add --name k8s-extension 
    az extension add --name customlocation

    az provider register --namespace Microsoft.ExtendedLocation
    az provider register --namespace Microsoft.Kubernetes 
    az provider register --namespace Microsoft.KubernetesConfiguration
}
Catch{}

$script = Read-Host -Prompt "Press Enter to continue:"

write-host "***********************************************************************************************"
write-host "**                   Create a new Resource Group for Arc Demo                                **"
write-host "***********************************************************************************************"

$rg = Read-Host - Prompt "Enter a name for your new Arc Demo Resource Group"

az group create --name $($rg) --location eastus

$script = Read-Host -Prompt "Press Enter to continue:"

write-host "***********************************************************************************************"
write-host "**     Check to see if Operations Management is enable in your subscription                  **"
write-host "***********************************************************************************************"

az provider show -n Microsoft.OperationsManagement -o table
az provider show -n Microsoft.OperationalInsights -o table

#az provider register --namespace Microsoft.OperationsManagement
#az provider register --namespace Microsoft.OperationalInsights

$script = Read-Host -Prompt "Press Enter to continue:"

write-host "***********************************************************************************************"
write-host "**                                  Create the AKS Cluster                                   **"
write-host "***********************************************************************************************"

$cluster = Read-Host - Prompt "Enter a name for your new AKS Cluster"

write-host "*** W A R N I N G *** Answering Yes will create a 3 node AKS cluster with an approximate cost of 840/mo if left running   ***"
write-host "*** If you choose to proceed, please delete your resource group after the demo to keep cost low.                          ***"

$response = Read-Host - Prompt "[Y} for YES, [N] for NO"

if ($response -eq "Y")
{
    az aks create --resource-group $rg --name $cluster --node-vm-size standard_D8s_v3 --node-count 3 --enable-addons monitoring --generate-ssh-keys
}
else 
{
    write-host "Aborting AKS installation"
    write-host "Exiting Script"    
}

az aks install-cli

az aks get-credentials --resource-group $rg --name $cluster

CMD.EXE /C .azure-kubectl\kubectl get nodes
CMD.EXE /C .azure-kubectl\kubectl get pods -A -o wide

$script = Read-Host -Prompt "Press Enter to continue:"

write-host "***********************************************************************************************"
write-host "**                      Installing Azure ARC for Kubernetes                                  **"
write-host "***********************************************************************************************"

az connectedk8s connect --name azurearc --resource-group $rg

az connectedk8s enable-features -n azurearc -g $rg --features cluster-connect custom-locations

az k8s-extension create --name azdata --extension-type microsoft.arcdataservices --cluster-type connectedClusters -c azurearc -g $rg --scope cluster --release-namespace arc --config Microsoft.CustomLocation.ServiceAccount=sa-bootstrapper

$script = Read-Host -Prompt "Press Enter to continue:"

write-host "***********************************************************************************************"
write-host "**                            Installing Custom Location                                     **"
write-host "***********************************************************************************************"

$rmid = az connectedk8s show -n azurearc -g $rg  --query id -o tsv
$extid = az k8s-extension show --name azdata --cluster-type connectedClusters -c azurearc -g $rg  --query id -o tsv

write-host "***********************************************************************************************"
write-host "** Pausing Script to allow kubernetes pods time to spin up prior to creating custom location **"
write-host "***********************************************************************************************"

$x = 2*60
$length = $x / 100
while($x -gt 0) {
  $min = [int](([string]($x/60)).split('.')[0])
  $text = " " + $min + " minutes " + ($x % 60) + " seconds left"
  Write-Progress "Pausing Script to wait for kubernetes PODS to spin up" -status $text -perc ($x/$length)
  start-sleep -s 1
  $x--
}

write-host "***********************************************************************************************"
write-host "**                            Installing Custom Location                                     **"
write-host "***********************************************************************************************"
az customlocation create -n ArcDemo -g $rg  --namespace arc --host-resource-id $rmid --cluster-extension-ids $extid

$script = Read-Host -Prompt "Press Enter to continue:"

write-host "***********************************************************************************************"
write-host "**                         Adding Service Principal to AAD                                   **"
write-host "***********************************************************************************************"

$Spname = $Spname+"-"+(New-Guid).ToString('N').Substring(0,4)
$spcreate = az ad sp create-for-rbac -n $Spname
$spobjs = $spcreate | ConvertFrom-Json

write-host "***********************************************************************************************"
write-host "**                         Copy and save the information Below                               **"
write-host "**     You will need this inforamation when createing the Data Controller in the portal      **"
write-host "***********************************************************************************************"
Write-host "**    Client Id       =  $($spobjs.appid)                                **"
write-host "**    Tenant Id       =  $($spobjs.tenant)                                 **"
write-host "**    Client Secret   =  $($spobjs.password)                                  **"
write-host "***********************************************************************************************"


