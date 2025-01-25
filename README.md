# PowerShell Hyper-V Cloud-init example

Created for the following post: https://www.wporter.org/getting-started-with-cloud-init-on-hyper-v

This will demonstrate using PowerShell to generate a basic Cloud-init config and stand up an AlmaLinux VM (from the [AlmaLinux Generic Cloud image](https://wiki.almalinux.org/cloud/Generic-cloud.html) on a Server 2025 host. What follows is an excerpt from the post I mentioned above.

# Dependencies
1. qemu-img (only if you need to convert GenericCloud images to VHDXes - Azure images MIGHT work out of the box)
2. genisoimage, mkisofs, xorriso, or oscdimg

You will also need a GenericCloud image of some kind to use this.

## Installing Dependencies (Windows)

qemu-img alone can be downloaded from Cloudbase Solutions (company that supports cloudbase-init, which is basically cloud-init for Windows): https://cloudbase.it/qemu-img-windows/.

PowerShell:

```PowerShell
(irm https://cloudbase.it/downloads/qemu-img-win-x64-2_3_0.zip -outfile qemu-img.zip) |
extract-archive .\qemu-img.zip
```

This will bring with it a few DLLs - don't throw them away:

```PowerShell
PS C:\Users\liam\projects\cloud-init-a9> gci qemu-img

    Directory: C:\Users\liam\projects\cloud-init-a9\qemu-img

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a---           9/18/2013  1:35 PM          86528 libgcc_s_sjlj-1.dll
-a---           3/30/2015  3:09 PM        2584872 libglib-2.0-0.dll
-a---           3/30/2015  3:10 PM          79707 libgthread-2.0-0.dll
-a---           3/30/2015  3:38 AM        1475928 libiconv-2.dll
-a---           3/30/2015  1:59 PM         464017 libintl-8.dll
-a---           9/18/2013  1:35 PM          18944 libssp-0.dll
-a---           6/16/2015  9:37 PM        5615492 qemu-img.exe
```

More complete QEMU binaries for Windows (include qemu-img) can be found at: https://qemu.weilnetz.de/w64/

oscdimg is a part of the Windows Assessment and Deployment Kit, which can be installed with the `winget` package manager, if you have that installed (24H2+, incl. Server 2025 have Winget working by default).

Note that installing the ADK this way will not prompt you to select which components to install - and, by default, the ADK has a 2gb footprint, which is a bit much for just a tool to build ISOs.

```cmd
winget install Microsoft.WindowsADK
```

Alternatively, you can download and run the ADK installer directly from Microsoft. If you do it this way, you can select only the "Deployment Tools" feature and save some disk space, or download and run the oscdimg installer alone.

```PowerShell
(irm https://go.microsoft.com/fwlink/?linkid=2196127 -method GET -outfile adksetup.exe) |
.\adksetup.exe
```

If you *install* the Deployment Tools, oscdimg will, by default, be at: `C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe`.

If you *download* the Deployment Tools, you won't be prompted to select which features you want, but can then navigate to the downloaded directory and run the oscdimg installer `Oscdimg (DesktopEditions)-x86_en-us.msi`.

If you downloaded the ADK to your Downloads directory, the path to the installer(s) including that for oscdimg would be `~\Downloads\ADK\Installers`.

I have an archive containing oscdimg.msi and its required .cab files. You could have an archive just like it. I'm not going to distribute it here, though, because Microsoft might get mad (probably not.)

For reference, those files are:

```PowerShell
Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a----         1/20/2025   8:15 PM          81130 52be7e8e9164388a9e6c24d01f6f1625.cab
-a----         1/20/2025   8:15 PM          80196 5d984200acbde182fd99cbfbe9bad133.cab
-a----         1/20/2025   8:15 PM          81299 9d2b092478d6cca70d5ac957368c00ba.cab
-a----         1/20/2025   8:16 PM          84314 bbf55224a0290f00676ddc410f004498.cab
-a----         1/19/2025  10:22 PM         417792 Oscdimg (DesktopEditions)-x86_en-us.msi
```

Finally, [here's a link to the Oscdimg help page at (on?) MS Learn.](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/oscdimg-command-line-options?view=windows-11)

## Installing Dependencies (Linux)

I typically use WSL on my workstation, so I figured I'd include this as well. It's a little easier to get going this way, but you might not want/be able to go the WSL route on a locked-down work laptop or Windows build box.

You can install both genisoimage and qemu-img on Debian 12 with:
```sh
# apt install genisoimage qemu-img
```
Both are in the default Debian 12 repositories.

On Enterprise Linux & friends (I use Alma), you'll have to install EPEL first.
```sh
# dnf install epel-release
# dnf install genisoimage qemu-img
```
# Converting a GenericCloud image to a VHDX

One command, once you've downloaded qemu-img somewhere.

```cmd
C:\Users\liam\projects\a9-ci-ex> .\qemu-img\qemu-img.exe convert -O vhdx C:\Users\liam\Downloads\AlmaLinux-9-GenericCloud-9.2-20230513.x86_64.qcow2 .\AlmaLinux-9-GenericCloud-9.2-20230513.x86_64.vhdx
```

Once you've got a VHDX, you can come up with some parameters:

```PowerShell
$ManicPgSQLParams = @{
	VMName = 'manictime-pgsql'
	VSwitchName = 'ext-untagged'
	OriginalVHDXPath = 'D:\VHDX\AlmaLinux-9-GenericCloud-122024.vhdx'
	Username = 'liam'
	PublicKey = 'ssh-ed25519 i-know-this-isn't-sensitive-but-you're-not-getting-it-free'
	Force = $true
}
```

and run the script!

Full list of parameters that may be set in its current state:

```txt
	param (
		[string]$VMName = 'manictime-pgsql',
		[string]$VMSwitchName = 'ext-untagged',
		[string]$OriginalVHDXPath = 'D:\VHDX\AlmaLinux-9-GenericCloud-122024.vhdx',
		[string]$CloudInitMetadataPath = 'C:\tmp\cloud-init',
		[string]$CloudInitMetadataOutPath = 'C:\tmp\cloud-init.iso',
        [string]$Username = 'cloud-user',
        [string]$PublicKey,
        #[securestring]$HashedPassword = 'aabbccddeeff',
		[int]$vCPUs = 8,
		[long]$Memory = 8GB,
        [bool]$Force = $false
	)
```

### VMName
Self explanatory, I hope
### VMSwitchName
The Hyper-V vSwitch you would like to attach the VM to.
### OriginalVHDXPath
The Cloud-init-ready image you would like to copy to create your new VM.
### CloudInitMetadataPath
Path to the directory that will be used for metadata.
### CloudInitMetadataOutPath
Path to the ISO image that will be created from said metadata.
### Username
The user that will be created in your VM with Cloud-init.
### PublicKey
The created user's SSH public key
### HashedPassword
If you'd like to use a password, you could uncomment this and the other relevant lines in the script.
To create a hashed password, use the mkpasswd utility, which can be acquired on any good platform (not Windows) in the whois package (Debian 12) or mkpasswd package (AlmaLinux 9- appstream).
### vCPUs
The number of threads to assign to the VM
### Memory
The amount of memory, in bytes, to assign to the VM
### Force
Optional flag to overwrite existing files instead of failing

Anyway. Yeah. This is an example I chucked together for a post, so don't judge me too harshly on the lack of code quality. I'd recommend reading the blog post (again, that's at https://www.wporter.org/getting-started-with-cloud-init-on-hyper-v) for the full deetz. Happy VM-ing-ing!

That's all for now, folks...
William
