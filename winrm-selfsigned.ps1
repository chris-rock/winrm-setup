#ps1

# Configure WinRM
# ---------------
#
# This script verifies the local WinRM configuration. If required, the
# script configures the machine to configure WinRm for remote access.
# 
# Written by Vulcano Security GmbH <chris@vulcanosec.com>
#
# Version 1.0 - June 08 th, 2015
#
# Usage:
# powershell -executionpolicy bypass -file .\winrm-selfsigned.ps1
#
# If you need verbose output, run
# powershell -executionpolicy bypass -file .\winrm-selfsigned.ps1 -verbose
# 

# allows to use -verbose parameter
[CmdletBinding(SupportsShouldProcess=$true)]

# no parameters at the moment
Param ()

Write "Verifying WinRM configuration"

# Default error handling for PowerShell
Trap
{
    Write "Error found:" 
    Write-Error $_
    Exit 1
}
# Stop the script if an error occurs
$ErrorActionPreference="Stop"

# Check all preconditions for running this script
Function CheckPreconditions
{
    Write "Check all preconditions"
    # Ensure we have at least Powershell 3
    If ($PSVersionTable.PSVersion.Major -lt 4)
    {
        Throw "This script required PowerShell version 3 or higher."
    }
}

# Start WinRM service
Function StartWinRMService
{
    Write "Start WinRM service"
    # WinRM Service not available
    If (!(Get-Service "WinRM"))
    {
        Throw "WinRM service not installed."
    }
    # WinRM Service is available, but not running
    ElseIf ((Get-Service "WinRM").Status -ne "Running")
    {
        Write-Verbose "Starting WinRM service."
        Start-Service -Name "WinRM" -ErrorAction Stop
    }
    Else {
        Write-Verbose "WinRM service already started."
    }
}

# Enable PowerShell Remoting
# should be enabled by default on Windwos 2012+
# https://technet.microsoft.com/en-us/library/hh849694.aspx
Function EnablePowerShellRemoting
{
    Write "Activate PowerShell Remoting"
    If (!(Get-PSSessionConfiguration -Verbose:$false) -or (!(Get-ChildItem WSMan:\localhost\Listener)))
    {
        Write-Verbose "Enabling PowerShell Remoting."
        Enable-PSRemoting -Force -ErrorAction Stop
    }
    Else
    {
        Write-Verbose "PowerShell Remoting is already enabled."
    }
}

# Enable BasicAuth
Function EnableBasicAuthentication
{
    Write "Enable Basic Authentication"
    $auth = Get-WSManInstance winrm/config/service/auth
    If ($auth.Basic -eq $false)
    {
        Write-Verbose "Enabling Basic Authentication."
        Set-WSManInstance winrm/config/service/auth -ValueSet @{Basic=$true} | Out-Null 
    }
    Else
    {
        Write-Verbose "Basic Authentication is already enabled."
    }
}

# Creates a new self-signed certificate
Function CreateSelfSignedCert ($hostname)
{
    Write-Verbose "Check if an certificate exists"
    $thumbprints = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$hostname"} | Select-Object -Property Thumbprint
    If ($thumbprints.length -eq 0)
    {
        Write "Create a new self-signed certificate for: $hostname"

        # see https://technet.microsoft.com/en-us/library/hh848633.aspx
        New-SelfSignedCertificate -DnsName $hostname -CertStoreLocation Cert:\LocalMachine\My
    }
    Else
    {
        Write-Verbose "Found existing certificate"
    }
}

# Configure HTTPS Listener
Function EnableHTTPSListener
{
    Write "Configure WinRM HTTPS Listener"
    Try
    {
        $listener = Get-WSManInstance winrm/config/listener -SelectorSet @{Address="*"; Transport="HTTPS"}
        If ($listener.Enabled -eq "False")
        {
            Write-Verbose "Enable HTTPS listener."
            # see https://technet.microsoft.com/en-us/library/hh849875.aspx
            Set-WSManInstance winrm/config/listener -SelectorSet @{Address="*";Transport="HTTPS"} -ValueSet @{Enabled="true"} | Out-Null
        }
        Else
        {
            Write-Verbose "HTTPS listener is already enabled."
        }
    }
    Catch {
        Write-Verbose "Add new HTTPS listener"
        $hostname = [System.Net.Dns]::GetHostName()
        CreateSelfSignedCert $hostname
        $thumbprints = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$hostname"} | Select-Object -Property Thumbprint
        $thumbprint = @($thumbprints)[0].Thumbprint
        # Create a WinRM Listener with thumbprint
        New-WSManInstance winrm/config/listener -SelectorSet @{Address="*";Transport="HTTPS"} -ValueSet @{Hostname=$hostname; CertificateThumbprint=$thumbprint} #| Out-Null
    }
}

# Configure Firewall for HTTPS
Function ConfigureFirewall
{
    Write "Configure Windows Firewall for WinRM with HTTPS"
    Try 
    {
        $firewall = Get-NetFirewallRule -DisplayName "Allow WinRM HTTP/SSL" -ErrorAction Stop
        If ($firewall.Enabled -eq "False")
        {
            Write-Verbose "Enable existing firewall rule."
            Enable-NetFirewallRule -DisplayName "Allow WinRM HTTP/SSL"
        }
        Else
        {
            Write-Verbose "Firewall rule is already enabled."
        }
    }
    Catch {
        Write-Verbose "Add new firewall rule for WinRM"
        New-NetFirewallRule -DisplayName "Allow WinRM HTTP/SSL" -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow | Out-Null
    }
}

Function LocalAccountPolicy
{
    write "Configure LocalAccountTokenFilterPolicy to grant administrative rights remotely to local users."
    set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system" -name "LocalAccountTokenFilterPolicy" -Value 1
}

Function TestPowerShellSession
{
    Write "Test Remote PowerShell setup."
    
    # test connections
    $httpRes = Invoke-Command -ComputerName "localhost" -ScriptBlock {$env:COMPUTERNAME} -ErrorVariable httpError -ErrorAction SilentlyContinue
    
    $httpsOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
    $httpsRes = New-PSSession -UseSSL -ComputerName "localhost" -SessionOption $httpsOptions -ErrorVariable httpsError -ErrorAction SilentlyContinue

    # print user output
    If ($httpRes)
    {
        Write-Verbose "WinRM HTTP sessions are enabled."
    }

    If ($httpRes)
    {
        Write-Verbose "WinRM HTTPS sessions are enabled."
    }

    If (!$httpRes -and !$httpsRes)
    {
        Write-Verbose "Unable to establish an HTTP or HTTPS remoting session."
    }

}

# Start script
CheckPreconditions
StartWinRMService
EnablePowerShellRemoting
EnableBasicAuthentication
EnableHTTPSListener
ConfigureFirewall
LocalAccountPolicy
TestPowerShellSession

Write "Configuration of WinRM complete"
