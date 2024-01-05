Function Test-IsAdmin {
    <#
    .SYNOPSIS
        Function to test if current session has administrator privileges
    .LINK
        https://devblogs.microsoft.com/scripting/use-function-to-determine-elevation-of-powershell-console/
    .INPUTS
        None
    .OUTPUTS
        System.Boolean
    #>
    [System.Security.Principal.WindowsIdentity]$Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    [System.Security.Principal.WindowsPrincipal]$Principal = New-Object -TypeName 'Security.Principal.WindowsPrincipal' -ArgumentList $Identity
    $Principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Update-self {
    <#
    .SYNOPSIS
        Make sure the latest version of the module is installed and if not, automatically update it, clean up any old versions
    .INPUTS
        None
    .OUTPUTS
        System.String
    #>

    [System.Version]$CurrentVersion = (Test-ModuleManifest -Path "$HardeningModulePath\Harden-Windows-Security-Module.psd1").Version

    try {
        [System.Version]$global:LatestVersion = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/HotCakeX/Harden-Windows-Security/main/Harden-Windows-Security%20Module/version.txt' -ProgressAction SilentlyContinue
    }
    catch {
        Write-Error -Message 'Could not verify if the latest version of the module is installed, please check your Internet connection.'
    }

    if ($CurrentVersion -lt $LatestVersion) {
        Write-Output -InputObject "$($PSStyle.Foreground.FromRGB(255,105,180))The currently installed module's version is $CurrentVersion while the latest version is $LatestVersion - Auto Updating the module... 💓$($PSStyle.Reset)"

        # Only attempt to auto update the module if running as Admin, because Controlled Folder Access exclusion modification requires Admin privs
        if (Test-IsAdmin) {

            Remove-Module -Name 'Harden-Windows-Security-Module' -Force

            try {
                # backup the current allowed apps list in Controlled folder access in order to restore them at the end of the script
                # doing this so that when we Add and then Remove PowerShell executables in Controlled folder access exclusions
                # no user customization will be affected
                [System.String[]]$CFAAllowedAppsBackup = (Get-MpPreference).ControlledFolderAccessAllowedApplications

                # Temporarily allow the currently running PowerShell executables to the Controlled Folder Access allowed apps
                # so that the script can run without interruption. This change is reverted at the end.
                foreach ($FilePath in (Get-ChildItem -Path "$PSHOME\*.exe" -File).FullName) {
                    Add-MpPreference -ControlledFolderAccessAllowedApplications $FilePath
                }

                # Do this if the module was installed properly using Install-module cmdlet
                Uninstall-Module -Name 'Harden-Windows-Security-Module' -AllVersions -Force
                Install-Module -Name 'Harden-Windows-Security-Module' -RequiredVersion $LatestVersion -Force
                Import-Module -Name 'Harden-Windows-Security-Module' -RequiredVersion $LatestVersion -Force -Global
            }
            # Do this if module files/folder was just copied to Documents folder and not properly installed - Should rarely happen
            catch {
                Install-Module -Name 'Harden-Windows-Security-Module' -RequiredVersion $LatestVersion -Force
                Import-Module -Name 'Harden-Windows-Security-Module' -RequiredVersion $LatestVersion -Force -Global
            }
            finally {
                # Reverting the PowerShell executables allow listings in Controlled folder access
                foreach ($FilePath in (Get-ChildItem -Path "$PSHOME\*.exe" -File).FullName) {
                    Remove-MpPreference -ControlledFolderAccessAllowedApplications $FilePath
                }

                # restoring the original Controlled folder access allow list - if user already had added PowerShell executables to the list
                # they will be restored as well, so user customization will remain intact
                if ($null -ne $CFAAllowedAppsBackup) {
                    Set-MpPreference -ControlledFolderAccessAllowedApplications $CFAAllowedAppsBackup
                }
            }
            # Make sure the old version isn't run after update
            Write-Output -InputObject "$($PSStyle.Foreground.FromRGB(152,255,152))Update successful, please run the cmdlet again.$($PSStyle.Reset)"
            break
            return
        }
        else {
            Write-Error -Message 'Please run the cmdlet as Admin to update the module.'
            break
        }
    }
}

# Self update the module
Update-self

if (Test-IsAdmin) {
    # check to make sure TPM is available and enabled
    [System.Object]$TPM = Get-Tpm
    if (-NOT ($TPM.tpmpresent -and $TPM.tpmenabled)) {
        Throw 'TPM is not available or enabled, please enable it in UEFI settings and try again.'
    }
}
