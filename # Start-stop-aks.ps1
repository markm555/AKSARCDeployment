# Script to deploy an AKS Cluster and install a custom location and ARC for Kubernetes
# This will provide you with a working platform capable of hosting all of the ARC services that run on Kubernetes
# Such as ARC Data Controller, ARC SQL MI, ARC Postgres (Citus), ARC Azure ML.  More services are coming to this platform
#
# 06/19/2021 - Created - Mark Moore (markm@microsoft.com)

cd $env:homepath
$ags = @(0...500)
$kclusters = @(0..500)
$selection = @(0..500)
$subname = @(0..500)

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
write-host "**                                   Installing Helm                                         **"
write-host "**  Per Marina Levin I have added the following line to resolve issues install choco         **"
#write-host "**   if (!(Test-Path -Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }      **"
write-host "***********************************************************************************************"

$helmtest = helm

if ($helmtest -eq $null)
{

    if (!(Test-Path -Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force } # Thanks Marina

    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    choco install kubernetes-helm -y
}
else 
{
    Write-Host "Helm already installed"
}

write-host "***********************************************************************************************"
write-host "**                      Login to Azure and Select a Subscription                             **"
write-host "***********************************************************************************************"

$textline ="|                                                                                                                       "

$sub = az login
$subs = $sub | ConvertFrom-Json
$i=0
$selection = @(0..500)
$subname = @(0..500)
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
        $subname[$i] = $($sub.name)
        $i=$i+1
        $textline ="|                                                                                                                                                "
    }
    $script = Read-Host -Prompt "Enter the number next to the subscription you would like to host AKS and all components for the demo"

    write-host "You selected this subscription"
    write-host $subname[$script]  $selection[$script] 
    $selectedscript = $($selection[$script])

    $goodselection = Read-Host -Prompt "Is this correct [Y] Yes, [N] No"
}


az account set --subscription $selection[$script]

write-host "***********************************************************************************************"
write-host "**                          Installing Kubernetes Extensions                                 **"
write-host "***********************************************************************************************"

try 
{
    az extension add --name connectedk8s 
    az extension add --name k8s-extension 
    az extension add --name k8s-configuration
    az extension add --name customlocation

    az provider register --namespace Microsoft.ExtendedLocation
    az provider register --namespace Microsoft.Kubernetes 
    az provider register --namespace Microsoft.KubernetesConfiguration
}
Catch{}

$startstop = "1000"

while($startstop -ne "E")
{
    clear
    write-host ""
    write-host "Select a cluster number to toggle it between running and stopped."  
    #write-host "If the cluster is running selecting it will stop the cluster"
    #write-host "If the cluster is stopped selecting it will start the cluster"

    $textline2 ="|                                                                                                                       "
    #write-host "         1         2          3         4         5         6         7         8"
    #write-host "123456789012345678901213456789012345678901234567890123456789012345678901234567890"
    write-host " _______________________________________________________________________________"
    write-host "|    |  Cluster Name      | Power State |   Resource Group   |      VM Size     |"
    write-host "|____|____________________|_____________|____________________|__________________|"
    $kclusters = az aks list

    $kclust = $kclusters | ConvertFrom-Json
    $i2 = 0
    while($null -ne $kclust[$i2])
    {
        $textline2 = $textline2.insert(2,$i2)
        $textline2 = $textline2.insert(5,'|')
        $textline2 = $textline2.insert(7,$($kclust[$i2].name))
        $textline2 = $textline2.insert(26,'|')
        $textline2 = $textline2.insert(28,$($kclust[$i2].powerstate.code))
        $textline2 = $textline2.insert(40,'|')
        $textline2 = $textline2.insert(42,$($kclust[$i2].resourcegroup))
        $textline2 = $textline2.insert(61,'|')
        $textline2 = $textline2.insert(63,$($kclust[$i2].agentPoolProfiles.vmSize))
        $textline2 = $textline2.insert(80,'|')

        write-host $textline2.substring(0,110)
        #write-host $i2 " | "$kclust[$i2].name " | " $kclust[$i2].powerstate.code " | " $kclust[$i2].resourceGroup " | " $kclust[$i2].location " | " $kclust[$i2].agenPoolProfiles.count
        $i2=$i2+1
        $textline2 ="|                                                                                                                                                "

    }
    write-host "|____|____________________|_____________|____________________|__________________|"

    $startstop = 500

    write-host $kclust[$startstop].powerstate.code
    $startstop = Read-Host -Prompt "Enter cluster number or E to exit"
    write-host $startstop
    write-host $kclust[$startstop].powerstate.code

    if($startstop -ne 500)
    {

        If($kclust[$startstop].powerstate.code -eq "Running")
        {
            write-host $startstop " " $kclust[$startstop].powerstate.code
            az aks stop --name $kclust[$startstop].name --resource-group $kclust[$startstop].resourceGroup
        }

        If($kclust[$startstop].powerstate.code -eq "Stopped")
        {
            write-host $startstop " " $kclust[$startstop].powerstate.code
            az aks start --name $kclust[$startstop].name --resource-group $kclust[$startstop].resourceGroup
        }

        
    }
}