# PowerShell Hyper-V Cloud-init example

Created for the following post: https://www.wporter.org/getting-started-with-cloud-init-on-hyper-v

This will demonstrate using PowerShell to generate a basic Cloud-init config and stand up an AlmaLinux VM from the [AlmaLinux Generic Cloud image](https://wiki.almalinux.org/cloud/Generic-cloud.html) on a Server 2025 or Windows 11 24H2 Hyper-V host. What follows is an excerpt from the linked post.

## TL:DR

Get a VHDX cloud-init image

To convert an image:

```PowerShell
(irm https://cloudbase.it/downloads/qemu-img-win-x64-2_3_0.zip -outfile qemu-img.zip); expand-archive .\qemu-img.zip

.\qemu-img\qemu-img.exe convert -O vhdx .\AlmaLinux-8-GenericCloud-latest.x86_64.qcow2 .\AlmaLinux-8-GenericCloud-latest.x86_64.vhdx
```

Get oscdimg

```txt
Import-Module .\cloudinit-vm.ps1
$bind = @{
  VMName = 'bind.lab.wporter.org'
  VMSwitchName = 'vlab0-natswitch'
  OriginalVHDXPath = '.\al9gc.vhdx'
  Username = 'liam'
  PublicKey = 'ssh-ed25519 Zn'
  Force = $true
  HashedPassword = ('foobar' | ConvertTo-SecureString -AsPlainText -Force)
}
CloudInit-VM @bind
```

Creating a hashed PW you can pass through:

```sh
liam@liam-z790-0:~$ salt=$(openssl rand -base64 16)
liam@liam-z790-0:~$ hashed_string=$(openssl passwd -6 -salt "$salt" foobar)
liam@liam-z790-0:~$ echo "$hashed_string"
$6$7oxzBYUGVIiTl7mK$u/VhUPQwTFi2TtwU7iKFbdIaWfKWzrYPxxmVxJI07Ulz2Wy4XHE6qS0zwsTZ9lYX2JK/TQLRtb77j2urZci.e/
```

## Dependencies

1. qemu-img (only if you need to convert GenericCloud images to VHDXes - Azure images MIGHT work out of the box)
2. genisoimage, mkisofs, xorriso, or oscdimg

You will also need a GenericCloud image of some kind to use this.

### Installing Dependencies (Windows)

#### qemu-img

qemu-img alone can be downloaded from Cloudbase Solutions (the company that supports the "cloud-init for Windows" tool cloudbase-init): https://cloudbase.it/qemu-img-windows/.

Get it with PowerShell:

```PowerShell
(irm https://cloudbase.it/downloads/qemu-img-win-x64-2_3_0.zip -outfile qemu-img.zip); expand-archive .\qemu-img.zip
```

The archive will look something like this:

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

More complete QEMU binaries for Windows (include qemu-img) can be found at: https://qemu.weilnetz.de/w64/.

#### oscdimg

oscdimg is a part of the Windows Assessment and Deployment Kit, which can be installed with the `winget` package manager, if you have that installed (24H2+, incl. Server 2025 have Winget working by default).

Note that installing the ADK this way will not prompt you to select which components to install - and, by default, the ADK has a 2gb footprint, which is a bit much for just a tool to build ISOs.

```cmd
winget install Microsoft.WindowsADK
```

Alternatively, you can download and run the ADK installer directly from Microsoft. If you do it this way, you can select only the "Deployment Tools" feature and save some disk space, or download and run the oscdimg installer alone.

```txt
(irm https://go.microsoft.com/fwlink/?linkid=2196127 -method GET -outfile adksetup.exe) |
.\adksetup.exe
```

If you *install* the Deployment Tools, oscdimg will, by default, be at: `C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe`.

If you *download* the Deployment Tools, you won't be prompted to select which features you want, but can then navigate to the downloaded directory and run the oscdimg installer `Oscdimg (DesktopEditions)-x86_en-us.msi`.

If you downloaded the ADK to your Downloads directory, the path to the installer(s) including that for oscdimg would be `~\Downloads\ADK\Installers`.

I have an archive containing oscdimg.msi and its required .cab files. This could be a useful way to quickly install just the component you want.

For reference, those files are:

```txt
Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a----         1/20/2025   8:15 PM          81130 52be7e8e9164388a9e6c24d01f6f1625.cab
-a----         1/20/2025   8:15 PM          80196 5d984200acbde182fd99cbfbe9bad133.cab
-a----         1/20/2025   8:15 PM          81299 9d2b092478d6cca70d5ac957368c00ba.cab
-a----         1/20/2025   8:16 PM          84314 bbf55224a0290f00676ddc410f004498.cab
-a----         1/19/2025  10:22 PM         417792 Oscdimg (DesktopEditions)-x86_en-us.msi
```

Finally, [here's a link to the Oscdimg help page at (on?) MS Learn.](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/oscdimg-command-line-options?view=windows-11)

### Installing Dependencies (Linux)

I typically use WSL on my workstation, so I figured I'd include this as well. It's a little easier to get qemu-img this way, but you might not want/be able to go the WSL route on a locked-down work laptop or Windows build box.

You can install both genisoimage and qemu-img on Debian 12 from the standard repositories:

```sh
# apt install genisoimage qemu-img
```

On Enterprise Linux & friends (I like to use Alma), you'll have to install EPEL first.

```sh
# dnf install epel-release
# dnf install genisoimage qemu-img
```

### Converting a GenericCloud image to a VHDX

This is one command (`qemu-img convert -O vhdx`), once you've downloaded qemu-img somewhere.

```cmd
.\qemu-img\qemu-img.exe convert -O vhdx GenericCloud.qcow2 .GenericCloud.vhdx
```

## Usage

Once you've got a VHDX, you can come up with some parameters:

```PowerShell
$ManicPgSQLParams = @{
  VMName = 'manictime-pgsql'
  VMSwitchName = 'ext-untagged'
  OriginalVHDXPath = 'D:\VHDX\AlmaLinux-9-GenericCloud-122024.vhdx'
  Username = 'liam'
  PublicKey = 'ssh-ed25519 ssh key here'
  Force = $true
}
```

Import the `cloudinit-vm.ps1` file (containing one function) as a module, then run the function, like so:

```PowerShell
CloudInit-VM @ManicPgSQLParams
```

Here's the full list of parameters that may be set in its current state:

```txt
param (
  [string]$VMName = 'manictime-pgsql',
  [string]$VMSwitchName = 'ext-untagged',
  [string]$OriginalVHDXPath = 'D:\VHDX\AlmaLinux-9-GenericCloud-122024.vhdx',
  [string]$CloudInitMetadataPath = 'C:\tmp\cloud-init',
  [string]$CloudInitMetadataOutPath = 'C:\tmp\cloud-init.iso',
  [string]$Username = 'cloud-user',
  [string]$PublicKey,
  [securestring]$HashedPassword = 'aabbccddeeff',
  [int]$vCPUs = 8,
  [long]$Memory = 8GB,
  [bool]$Force = $false
)
```

### VMName

Self explanatory

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
To create a hashed password, use the mkpasswd utility provided by the whois package (Debian 12) or mkpasswd package (AlmaLinux 9 appstream). Alternatively, you can use OpenSSL directly:

```sh
liam@liam-z790-0:~$ salt=$(openssl rand -base64 16)
liam@liam-z790-0:~$ hashed_string=$(openssl passwd -6 -salt "$salt" foobar)
liam@liam-z790-0:~$ echo "$hashed_string"
$6$7oxzBYUGVIiTl7mK$u/VhUPQwTFi2TtwU7iKFbdIaWfKWzrYPxxmVxJI07Ulz2Wy4XHE6qS0zwsTZ9lYX2JK/TQLRtb77j2urZci.e/
```

You can probably use OpenSSL for Windows. There is no native way to do this, as far as I'm aware, because the SHA-512-CRYPT algorithm is not implemented by .NET cryptography libraries.

### vCPUs

The number of threads to assign to the VM

### Memory

The amount of memory, in bytes, to assign to the VM

### Force

Optional flag to overwrite existing files instead of failing

Anyway. Yeah. This is an example I chucked together for a post, so don't judge me too harshly on the lack of code quality. I'd recommend reading the blog post (again, that's at https://www.wporter.org/getting-started-with-cloud-init-on-hyper-v) for the full deetz. Happy VM-ing-ing!
