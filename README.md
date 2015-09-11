# Setup WinRm for Windows via cloudinit

This script is intended to simplify the setup of a WinRM server. The script is tested with Windows 2012 R2. This script requires at least PowerShell 4.

## AWS Cloudinit

Please use the following script `winrm-selfsigned.ps1` for EC2Config on AWS:

```xml
<powershell>
# Content of winrm-selfsigned.ps1 goes here
</powershell>
```

## OpenStack Userdata

The script can directly be used in combination with OpenStack. Please ensure that your Windows image has [Cloudinit](https://github.com/stackforge/cloudbase-init) installed.

```bash
nova boot \
--user-data winrm-selfsigned.ps1 \
--image "Windows Server 2012 R2 Std" \
--key-name windows \
--flavor m1.medium \
--security-groups default windows
```

## Security Group Configuration

Configure your security group for either port 5985 (http) or 5986 (https). We recommend using port 5986 only.

## Reference

* Richard Downer did a great job with its [WinRM tools](https://github.com/rdowner/winrm-tools/). This project is built on top of Powershell 4 while Richards project supports Powershell 1.

## Author

* Christoph Hartmann <chris@lollyrock.com>
