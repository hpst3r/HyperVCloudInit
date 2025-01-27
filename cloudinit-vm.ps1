Function CloudInit-VM {
	param (
		[string]$VMName = 'my-vm',
		[string]$VMSwitchName = 'untagged',
		[string]$OriginalVHDXPath = 'D:\ISOs\AlmaLinux-9-GenericCloud-122024.vhdx',
		[string]$CloudInitMetadataPath = 'C:\tmp\cloud-init',
		[string]$CloudInitMetadataOutPath = 'C:\tmp\cloud-init.iso',
        [string]$Username = 'cloud-user',
        [string]$PublicKey,
        #[securestring]$HashedPassword = 'aabbccddeeff',
		[int]$vCPUs = 8,
		[long]$Memory = 8GB,
        [bool]$Force = $false
	)

	Function Set-MetadataFile {
		param (
			[string]$ParentPath,
			[string]$Content,
			[string]$MetadataType,
            [bool]$Force
		)

        if (-not (Test-Path -Path $ParentPath)) {
            New-Item `
                -ItemType Directory `
                -Path $ParentPath
        }

        Write-Host -Object `
            "Generating $($MetadataType)-data file for cloud-init at $($ParentPath)\$($MetadataType)-data."

		if ( (-not ( Test-Path -Path "$($ParentPath)\$($MetadataType)-data" )
            ) -or $Force) {
	
            $MetadataFile = @{
                Path = "$($CloudInitMetadataPath)\$($MetadataType)-data"
                Value = $Content
            }
            
            Set-Content @MetadataFile 
		
		} else {
		
			Write-Error -Message `
				"$($MetadataType)-data file in $($Path) already exists and -Force is not set. Exiting."
				
			return 1
			
		}

	}

	# populate the meta-data file

    $MetadataFile = @{
        ParentPath = $CloudInitMetadataPath
        Content = @"
instance-id: $VMName
local-hostname: $VMName
"@
        MetadataType = 'meta'
        Force = $Force
    }

    # populate the user-data file with ssh public key and username

    Set-MetadataFile @MetadataFile

    # if you want to pass a password, generate it with mkpasswd, and add, under your user:
    # hashed_passwd: $(ConvertFrom-SecureString -SecureString $HashedPassword -AsPlainText)
    # and set lock_passwd to False
    $UserdataFile = @{
        ParentPath = $CloudInitMetadataPath
        Content = @"
#cloud-config
users:
- name: $Username
  groups: users,wheel
  sudo: ALL=(ALL) NOPASSWD:ALL
  shell: /bin/bash
  lock_passwd: True
  ssh_authorized_keys:
   - $PublicKey

ssh_pwauth: False
"@
        MetadataType = 'user'
        Force = $Force
    }

    Set-MetadataFile @UserdataFile

    # convert metadata files to a Joliet cloud-init ISO
	
	& C:\Program` Files` `(x86`)\Windows` Kits\10\Assessment` and` Deployment` Kit\Deployment` Tools\amd64\Oscdimg\oscdimg.exe -j1 -lcidata -r $CloudInitMetadataPath $CloudInitMetadataOutPath
	
	# make a copy of the base vhdx - put it under the configured default vhdx path on the host

	$NewVHDXPath = "$((Get-VMHost).VirtualHardDiskPath)\$($VMName).vhdx"
	
	Write-Host -Object `
		"Checking for existence of path $($NewVHDXPath)."
		
	if (Test-Path -Path $NewVHDXPath) {
		# if the -Force flag IS NOT set, do not overwrite the existing VHDX and terminate.
		if (-not $Force) {
		
			Write-Error -Message `
				'Default new VHDX path is already occupied and -Force is not set. Exiting.'
			return 1
			
		}
		
		# if the -Force flag IS set, attempt to remove the existing VHDX.
		# This WILL NOT SUCCEED if a VM is using said VHDX.
		
		if ($Force) {
		
			Write-Host -Object `
				"-Force is set. Attempting to remove VHDX at $($NewVHDXPath)."
				
			try {
			
				Remove-Item `
					-Path $NewVHDXPath `
					-Force `
					-Confirm:$false `
					-ErrorAction 'Stop'
					
			} catch {
			
				Write-Error -Message @"
-Force is set, but failed to remove existing file at desired clone VHDX path $($NewVHDXPath).
$($_)
Terminating.
"@

                return 1

			}
		}
	}

    # copy the VM template VHDX for our new VM.

	Write-Host -Object `
		"Copying template VHDX from $($OriginalVHDXPath) to $($NewVHDXPath)."

	try {

		Copy-Item -Path $OriginalVHDXPath -Destination $NewVHDXPath

	} catch {

		Write-Error -Message `
			"Copy failed with error: $($_). Terminating."

        return 1

	}

	Write-Host -Object @"
Attempting to create VM $($VMName) with specifications:

Threads: $($vCPUs)
Memory (Mb): $($Memory/([Math]::Pow(2,20)))
Switch: $($VMSwitchName)

"@

	try {
		# create the VM
		$VMParams = @{
			Name = $VMName
			SwitchName = $VMSwitchName
			Generation = 2
			MemoryStartupBytes = "$($Memory)" # is there a reason for this?
			ErrorAction = 'Stop'
		}
		
		$VM = New-VM @VMParams
	} catch {

		Write-Error -Message @"
Failed to create VM $($VMName) with error:
$($_)
Terminating script.
"@
		return 1

	}

    # assign vCPUs
    Set-VMProcessor -VM $VM -Count $vCPUs
	
	# add the copy of the VHDX to the VM
    
    Write-Host -Object `
        "Assigning clone VHDX $($NewVHDXPath) to VM $($VMName)."

    try {

        $VMDiskParams = @{
            VM = $VM
            ControllerType = 'SCSI'
            ControllerNumber = 0
            ControllerLocation = 0
            Path = $NewVHDXPath
            ErrorAction = 'Stop'
        }
        
        Add-VMHardDiskDrive @VMDiskParams

    } catch {

        Write-Error -Message `
            "Assigning VHDX $($NewVHDXPath) to VM $($VMName) failed with error: $($_). Terminating."

        return 1

    }

	# configure Secure Boot to allow non-MS signatures
	# you can also set by GUID 272e7447-90a4-4563-a4b9-8e4ab00526ce

    Write-Host -Object `
        "Setting $($VMName)'s UEFI to allow third-party Secure Boot signatures."

	Set-VMFirmware -VM $VM -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
	
	# add the cloud-init metadata image to the VM

    Write-Host -Object `
        "Assigning the $($CloudInitMetadataOutPath) metadata image to VM $($VMName)."
    
    try {

        $VMDvdParams = @{
            VM = $VM
            ControllerNumber = 0
            ControllerLocation = 1
            Path = $CloudInitMetadataOutPath
            ErrorAction = 'Stop'
        }
        
        Add-VMDvdDrive @VMDvdParams

    } catch {

        Write-Error -Message `
            "Failed to assign $($CloudInitMetadataOutPath) to VM $($VMName) with error: $($_). Terminating."

        return 1

    }

    # make sure first boot device is the cloned VHDX

    Write-Host -Object `
        "Setting VM $($VMName)'s first boot device to its hard drive (cloned VHDX.)"

	Set-VMFirmware -VM $VM -FirstBootDevice (Get-VMHardDiskDrive -VM $VM)
	
	# start the VM

    Write-Host -Object `
        "Starting VM $($VMName)."

	try {

        $StartVM = @{
            VM = $VM
            ErrorAction = 'Stop'
        }
    
        Start-VM @StartVM

    } catch {

        Write-Error -Message `
            "Failed to start VM $($VMName) with error: $($_). Terminating."

        return 1

    }

    # wait for Cloud-init
    Write-Host -Object `
        'Waiting 30 seconds for cloud-init.'

	Start-Sleep(30)
	
	# remove the Cloud-init disk

    Write-Host -Object `
        "Removing cloud-init drive from VM $($VMName)."
        
	Remove-VMDVDDrive -VMName $VM.Name -ControllerNumber 0 -ControllerLocation 1

    Write-Host -Object @"

Successfully created VM $($VMName) with:

Threads: $($vCPUs)
Memory (Mb): $($Memory/([Math]::Pow(2,20)))
Switch: $($VMSwitchName)

Original VHDX: $($OriginalVHDXPath)
Cloned VHDX: $($NewVHDXPath)

Generated cloud-init ISO: $($CloudInitMetadataOutPath)

"@

    Return 0
}
