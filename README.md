# Setup WinRm for Windows via cloudinit

This script is intended to simplify the setup of a WinRM server. Although it is intended to work with VulcanoSec suite, it does no special configuration for VulcanoSec.

The script is tested with Windows 2012 R2.

## AWS Cloudinit

Configure your security group for either port 5985 (http) or 5986 (https). We recommend using port 5986 only.

Please use the script `winrm-selfsigned.ps1` for EC2Config:


```xml
<powershell>
# Content of winrm-selfsigned.ps1 goes here
</powershell>
```

## OpenStack Userdata

The script can directly be used in combination with OpenStack.

```bash
nova boot \
--user-data winrm-selfsigned.ps1 \
--image "Windows Server 2012 R2 Std" \
--key-name windows \
--flavor m1.medium \
--security-groups default windows
```

# References

 * https://github.com/rdowner/winrm-tools/blob/master/WinRM-Tools/winrm.ps1

