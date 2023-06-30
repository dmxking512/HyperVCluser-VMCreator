#Clear Any variables set to avoid duplication
Remove-Variable * -ErrorAction SilentlyContinue
#Banner messages
Write-Host "-----------------------------------------"
Write-Host "---- Cluster VM Creator Tool - V1.2 -----"
write-host "-----------------------------------------"
# Prompt for virtual machine name
$vmName = Read-Host "Enter the name of the virtual machine"

# Prompt for generation
$generation = Read-Host "Enter the generation of the virtual machine (1 or 2)"

# Prompt for number of virtual CPUs
$vcpuCount = Read-Host "Enter the number of virtual CPUs"

# Prompt for amount of RAM
$ramSize = Read-Host "Enter the amount of RAM (Numeic Value only in GB)"

# Convert the RAM size value to an integer
$ramSizeBytes = [UInt64]$ramSize * 1GB

# Prompt for number of virtual network adapters
$networkCount = Read-Host "Enter the number of virtual network adapters"

# Create an array to store network adapter information
$networkAdapters = @()

# Prompt for VLAN and network adapter information
for ($i = 1; $i -le $networkCount; $i++) {
    $vlan = Read-Host "Enter the VLAN for network adapter $i"
    $networkAdapter = @{
        Name = "NetworkAdapter$i"
        VLAN = $vlan
    }
    $networkAdapters += $networkAdapter
}

# Get a list of available cluster storage volumes & their space
$clusterVolumes = Get-ClusterSharedVolume 
#Count the number of Volumes
$volumeCount = $clusterVolumes.Count

Write-Host "Available Cluster Volumes:"
for ($i = 0; $i -lt $clusterVolumes.Count; $i++) {
    $volume = $clusterVolumes[$i]
    $volumeName = $volume.Name
    $friendlyVolumeName = $volume.SharedVolumeInfo.FriendlyVolumeName
    #Query for free space on volume
    $getfreespace = Get-ClusterSharedVolume -Name $volumeName |  select -Property Name -ExpandProperty SharedVolumeInfo
    $freespacegb= "{0:N2}" -f ($getfreespace.Partition.FreeSpace/1024/1024/1024)
    #List the volume and its available space
    Write-Host "$($i + 1). $VolumeName | Free Space: $freespacegb GB"
}

# Validate and retrieve the selected volume
do {
    $volumeSelection = Read-Host "Enter the number of the Failover Cluster volume for the virtual machine"
    $volumeIndex = $volumeSelection - 1
}
while ($volumeIndex -lt 0 -or $volumeIndex -ge $clusterVolumes.Count)

#Load Volume path into variable
$getselectedVolume = Get-ClusterSharedVolume -Name $clusterVolumes[$volumeIndex].Name |  select -Property Name -ExpandProperty SharedVolumeInfo
$selectedVolume = $getselectedVolume.FriendlyVolumeName

# Create a folder for the virtual machine based on the virtual machine name
$vmFolderPath = Join-Path -Path $selectedVolume -ChildPath $vmName


# Create a folder for the virtual hard disk based on the virtual machine name
$diskFolderPath = Join-Path -Path $vmFolderPath -ChildPath "Virtual Hard Disks"
New-Item -ItemType Directory -Path $diskFolderPath | Out-Null


# Prompt for the option to use Windows Server 2019 template
$applyTemplate = Read-Host "Do you want to apply the Windows Server 2019 template? (yes/no)"

if ($applyTemplate -eq "yes" -or $applyTemplate -eq "y" -or $applyTemplate -eq "Y") {
    Write-Output "Give me a few moments while i copy the template for you..."
    # Copy existing virtual hard disk image for template
    # Replace with the actual template disk path
    $templateDiskPath = "C:\ClusterStorage\Volume1\templates\WinSer2019Template.vhdx"  
    $diskFilePath = Join-Path -Path $diskFolderPath -ChildPath "$vmName.vhdx"
    #Use BITSTransfer to Copy Template file    
    Import-Module BitsTransfer
    Start-BitsTransfer -Source $templateDiskPath -Destination $diskFilePath -TransferType Download

    # Prompt for extending the disk size
    $extendDisk = Read-Host "Do you want to extend the OS virtual hard disk size? (yes/no)"

    if ($extendDisk -eq "yes" -or $extendDisk -eq "y" -or $extendDisk -eq "Y") {
        # Prompt for new disk size
        $newDiskSize = Read-Host "Enter the new hard disk size (Numeic Value only in GB)"
        $newdiskSizeBytes = [UInt64]$newDiskSize * 1GB

        # Extend the virtual hard disk size
        Resize-VHD -Path $diskFilePath -SizeBytes $newdiskSizeBytes -Confirm:$false
    }
    
}
else {
        # Prompt for hard disk size
        $diskSize = Read-Host "Enter the hard disk size (Numeic Value only in GB)"

        # Create and attach the virtual hard disk
        $diskFilePath = Join-Path -Path $diskFolderPath -ChildPath "$vmName.vhdx"
        # Convert the disk size from GB to bytes
        $diskSizeBytes = [UInt64]$diskSize * 1GB
        New-VHD -Path $diskFilePath -SizeBytes $diskSizeBytes -Dynamic -Confirm:$false
    
}

#Promt for a Data Drive
$MakeDataDisk = Read-Host "Do you want to add another Drive for Data? (yes/no)"

if ($MakeDataDisk -eq "yes" -or $MakeDataDisk -eq "y" -or $MakeDataDisk -eq "Y") {
    $DatadiskSize = Read-Host "Enter the hard disk size (Numeic Value only in GB)"
    # Create and attach the virtual hard disk
    $DataDiskName = $vmName+"-Data"
    $DatadiskFilePath = Join-Path -Path $diskFolderPath -ChildPath "$DataDiskName.vhdx"
    # Convert the disk size from GB to bytes
    $DatadiskSizeBytes = [UInt64]$DatadiskSize * 1GB
    New-VHD -Path $DatadiskFilePath -SizeBytes $DatadiskSizeBytes -Dynamic -Confirm:$false

}



# Create the virtual machine
New-VM -Name $vmName -Generation $generation -Path $selectedVolume
Add-VMHardDiskDrive -VMName $vmName -Path $diskFilePath
#If a Data Disk was created, attach it to the VM.
if ($MakeDataDisk -eq "yes" -or $MakeDataDisk -eq "y" -or $MakeDataDisk -eq "Y"){
    Add-VMHardDiskDrive -VMName $vmName -Path $DatadiskFilePath
}

# Configure virtual machine settings
Set-VM -Name $vmName -ProcessorCount $vcpuCount -MemoryStartupBytes $ramSizeBytes


# Configure network adapters
foreach ($adapter in $networkAdapters) {
    $vlan = $adapter.VLAN
    $name = $adapter.Name
    $vlanIdList = $vlan -split ',' | ForEach-Object { $_.Trim() }
    #replace this with the name of your Hyper-V Virtual Switch
    $switchName = 'Your_Hyper-V-Virtual_Switch_Name'
    Add-VMNetworkAdapter -VMName $vmName -Name $name -SwitchName $switchName
    Set-VMNetworkAdapterVlan -VMName $vmName -VMNetworkAdapterName $name -Access -VlanId $vlan
    $NewNicName = "NIC_VLAN - " + $vlan
    Rename-VMNetworkAdapter -VMName $vmName -Name $name -NewName $NewNicName

}


#Remove the Default created network adapter
Remove-VMNetworkAdapter -VMName $vmName -VMNetworkAdapterName "Network Adapter"


#Update the Notes with the creation date and creator
$createdDate = Get-Date -Format "dd-MM-yyyy"
$createdBy = $env:USERNAME
Set-VM -VMName $vmName -Notes "Created on $createdDate by $createdBy"


# Add the virtual machine to the failover cluster
Add-ClusterVirtualMachineRole -VMName $vmName

# Get the list of available nodes in the Failover Cluster
$clusterNodes = Get-ClusterNode | Select-Object -ExpandProperty Name

# Prompt to select the destination node for live migration
Write-Host "Available Cluster Nodes:"
for ($i = 0; $i -lt $clusterNodes.Count; $i++) {
    Write-Host "$($i+1). $($clusterNodes[$i])"
}

do {
    $nodeSelection = Read-Host "Enter the number of the destination host to start the VM on"
    $nodeIndex = $nodeSelection - 1
}
while ($nodeIndex -lt 0 -or $nodeIndex -ge $clusterNodes.Count)

$destinationNode = $clusterNodes[$nodeIndex]

# Live migrate the Virtual Machine to the selected node
Move-ClusterGroup -Name $vmName -Node $destinationNode


# Start the virtual machine
Start-ClusterGroup $vmName

#Prompt to Launch the VM console
$LaunchConsole = Read-Host "Do you want to connect to the VM console? (yes/no)"

    if ($LaunchConsole -eq "yes" -or $LaunchConsole -eq "y" -or $LaunchConsole -eq "Y") {

    Start-Process -FilePath "vmconnect.exe" -ArgumentList "$destinationNode $vmName"

    }
