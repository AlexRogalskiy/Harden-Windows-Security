Function Edit-SignedWDACConfig {
    [CmdletBinding(
        DefaultParameterSetName = 'Allow New Apps Audit Events',
        SupportsShouldProcess = $true,
        PositionalBinding = $false,
        ConfirmImpact = 'High'
    )]
    Param(
        [Alias('E')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps Audit Events')][System.Management.Automation.SwitchParameter]$AllowNewAppsAuditEvents,
        [Alias('A')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps')][System.Management.Automation.SwitchParameter]$AllowNewApps,
        [Alias('M')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Merge Supplemental Policies')][System.Management.Automation.SwitchParameter]$MergeSupplementalPolicies,
        [Alias('U')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Update Base Policy')][System.Management.Automation.SwitchParameter]$UpdateBasePolicy,

        [ValidatePattern('^[a-zA-Z0-9 ]+$', ErrorMessage = 'The Supplemental Policy Name can only contain alphanumeric and space characters.')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Allow New Apps Audit Events', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'Allow New Apps', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'Merge Supplemental Policies', ValueFromPipelineByPropertyName = $true)]
        [System.String]$SuppPolicyName,

        [ValidatePattern('\.xml$')]
        [ValidateScript({ Test-Path -Path $_ -PathType 'Leaf' }, ErrorMessage = 'The path you selected is not a file path.')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Merge Supplemental Policies', ValueFromPipelineByPropertyName = $true)]
        [System.String[]]$SuppPolicyPaths,

        [Parameter(Mandatory = $false, ParameterSetName = 'Merge Supplemental Policies')]
        [System.Management.Automation.SwitchParameter]$KeepOldSupplementalPolicies,

        [ValidateSet([BasePolicyNamez])]
        [Parameter(Mandatory = $true, ParameterSetName = 'Update Base Policy')]
        [System.String[]]$CurrentBasePolicyName,

        [ValidateSet('AllowMicrosoft_Plus_Block_Rules', 'Lightly_Managed_system_Policy', 'DefaultWindows_WithBlockRules')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Update Base Policy')]
        [System.String]$NewBasePolicyType,

        [ValidatePattern('\.cer$')]
        [ValidateScript({ Test-Path -Path $_ -PathType 'Leaf' }, ErrorMessage = 'The path you selected is not a file path.')]
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [System.String]$CertPath,

        [ValidatePattern('\.xml$')]
        [ValidateScript({
                # Validate each Policy file in PolicyPaths parameter to make sure the user isn't accidentally trying to
                # Edit an Unsigned policy using Edit-SignedWDACConfig cmdlet which is only made for Signed policies
                $_ | ForEach-Object -Process {
                    $xmlTest = [System.Xml.XmlDocument](Get-Content -Path $_)
                    $RedFlag1 = $xmlTest.SiPolicy.SupplementalPolicySigners.SupplementalPolicySigner.SignerId
                    $RedFlag2 = $xmlTest.SiPolicy.UpdatePolicySigners.UpdatePolicySigner.SignerId
                    $RedFlag3 = $xmlTest.SiPolicy.PolicyID
                    $CurrentPolicyIDs = ((&'C:\Windows\System32\CiTool.exe' -lp -json | ConvertFrom-Json).Policies | Where-Object -FilterScript { $_.IsSystemPolicy -ne 'True' }).policyID | ForEach-Object -Process { "{$_}" }
                    if ($RedFlag1 -or $RedFlag2) {
                        # Ensure the selected base policy xml file is deployed
                        if ($CurrentPolicyIDs -contains $RedFlag3) {
                            return $True
                        }
                        else { throw "The currently selected policy xml file isn't deployed." }
                    }
                    # This throw is shown only when User added a Signed policy xml file for Unsigned policy file path property in user configuration file
                    # Without this, the error shown would be vague: The variable cannot be validated because the value System.String[] is not a valid value for the PolicyPaths variable.
                    else { throw 'The policy xml file in User Configurations for SignedPolicyPath is Unsigned policy.' }
                }
            }, ErrorMessage = 'The selected policy xml file is Unsigned. Please use Edit-WDACConfig cmdlet to edit Unsigned policies.')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps Audit Events', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'Merge Supplemental Policies', ValueFromPipelineByPropertyName = $true)]
        [System.String[]]$PolicyPaths,

        [ValidateScript({
                [System.String[]]$Certificates = foreach ($cert in (Get-ChildItem -Path 'Cert:\CurrentUser\my')) {
                (($cert.Subject -split ',' | Select-Object -First 1) -replace 'CN=', '').Trim()
                }
                $Certificates -contains $_
            }, ErrorMessage = "A certificate with the provided common name doesn't exist in the personal store of the user certificates." )]
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [System.String]$CertCN,

        [ValidateRange(1024KB, 18014398509481983KB)][Parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps Audit Events')]
        [System.Int64]$LogSize,

        [parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps Audit Events')]
        [parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps')]
        [System.Management.Automation.SwitchParameter]$NoScript,

        [parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps Audit Events')]
        [parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps')]
        [System.Management.Automation.SwitchParameter]$NoUserPEs,

        [ValidateSet('OriginalFileName', 'InternalName', 'FileDescription', 'ProductName', 'PackageFamilyName', 'FilePath')]
        [parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps Audit Events')]
        [parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps')]
        [System.String]$SpecificFileNameLevel,

        [parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps Audit Events')][System.Management.Automation.SwitchParameter]$IncludeDeletedFiles,

        [ValidateSet([Levelz])]
        [parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps Audit Events')]
        [parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps')]
        [System.String]$Level = 'FilePublisher',

        [ValidateSet([Fallbackz])]
        [parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps Audit Events')]
        [parameter(Mandatory = $false, ParameterSetName = 'Allow New Apps')]
        [System.String[]]$Fallbacks = 'Hash',

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [System.String]$SignToolPath,

        [Parameter(Mandatory = $false, ParameterSetName = 'Update Base Policy')]
        [System.Management.Automation.SwitchParameter]$RequireEVSigners,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.SwitchParameter]$SkipVersionCheck
    )

    begin {
        # Importing the required sub-modules
        Write-Verbose -Message 'Importing the required sub-modules'
        Import-Module -FullyQualifiedName "$ModuleRootPath\Shared\Update-self.psm1" -Force -Verbose:$false
        Import-Module -FullyQualifiedName "$ModuleRootPath\Shared\Get-SignTool.psm1" -Force -Verbose:$false
        Import-Module -FullyQualifiedName "$ModuleRootPath\Shared\Confirm-CertCN.psm1" -Force -Verbose:$false
        Import-Module -FullyQualifiedName "$ModuleRootPath\Shared\Get-GlobalRootDrives.psm1" -Force -Verbose:$false
        Import-Module -FullyQualifiedName "$ModuleRootPath\Shared\Write-ColorfulText.psm1" -Force -Verbose:$false
        Import-Module -FullyQualifiedName "$ModuleRootPath\Shared\Set-LogSize.psm1" -Force -Verbose:$false
        Import-Module -FullyQualifiedName "$ModuleRootPath\Shared\Test-FilePath.psm1" -Force -Verbose:$false
        Import-Module -FullyQualifiedName "$ModuleRootPath\Shared\Get-AuditEventLogsProcessing.psm1" -Force -Verbose:$false
        Import-Module -FullyQualifiedName "$ModuleRootPath\Shared\New-EmptyPolicy.psm1" -Force -Verbose:$false
        Import-Module -FullyQualifiedName "$ModuleRootPath\Shared\Get-RuleRefs.psm1" -Force -Verbose:$false
        Import-Module -FullyQualifiedName "$ModuleRootPath\Shared\Get-FileRules.psm1" -Force -Verbose:$false
        Import-Module -FullyQualifiedName "$ModuleRootPath\Shared\Get-BlockRulesMeta.psm1" -Force -Verbose:$false

        if (-NOT $SkipVersionCheck) { Update-self }

        #region User-Configurations-Processing-Validation
        # If any of these parameters, that are mandatory for all of the position 0 parameters, isn't supplied by user
        if (!$PolicyPaths -or !$SignToolPath -or !$CertPath -or !$CertCN) {
            # Read User configuration file if it exists
            $UserConfig = Get-Content -Path "$UserAccountDirectoryPath\.WDACConfig\UserConfigurations.json" -ErrorAction SilentlyContinue
            if ($UserConfig) {
                # Validate the Json file and read its content to make sure it's not corrupted
                try { $UserConfig = $UserConfig | ConvertFrom-Json }
                catch {
                    Write-Error -Message 'User Configurations Json file is corrupted, deleting it...' -ErrorAction Continue
                    # Calling this function with this parameter automatically does its job and breaks/stops the operation
                    Set-CommonWDACConfig -DeleteUserConfig
                }
            }
        }

        # Get SignToolPath from user parameter or user config file or auto-detect it
        if ($SignToolPath) {
            $SignToolPathFinal = Get-SignTool -SignToolExePath $SignToolPath
        } # If it is null, then Get-SignTool will behave the same as if it was called without any arguments.
        else {
            $SignToolPathFinal = Get-SignTool -SignToolExePath ($UserConfig.SignToolCustomPath ?? $null)
        }

        # If CertPath parameter wasn't provided by user
        if (!$CertPath) {
            if ($UserConfig.CertificatePath) {
                # validate user config values for Certificate Path
                if (Test-Path -Path $($UserConfig.CertificatePath)) {
                    # If the user config values are correct then use them
                    $CertPath = $UserConfig.CertificatePath
                }
                else {
                    throw 'The currently saved value for CertPath in user configurations is invalid.'
                }
            }
            else {
                throw "CertPath parameter can't be empty and no valid configuration was found for it."
            }
        }

        # If CertCN was not provided by user
        if (!$CertCN) {
            if ($UserConfig.CertificateCommonName) {
                # Check if the value in the User configuration file exists and is valid
                if (Confirm-CertCN -CN $($UserConfig.CertificateCommonName)) {
                    # if it's valid then use it
                    $CertCN = $UserConfig.CertificateCommonName
                }
                else {
                    throw 'The currently saved value for CertCN in user configurations is invalid.'
                }
            }
            else {
                throw "CertCN parameter can't be empty and no valid configuration was found for it."
            }
        }

        # If PolicyPaths has no values
        if (!$PolicyPaths) {
            # make sure the ParameterSet being used has PolicyPaths parameter - Then enforces "mandatory" attribute for the parameter
            if ($PSCmdlet.ParameterSetName -in 'Allow New Apps Audit Events', 'Allow New Apps', 'Merge Supplemental Policies') {
                if ($UserConfig.SignedPolicyPath) {
                    # validate each policyPath read from user config file
                    if (Test-Path -Path $($UserConfig.SignedPolicyPath)) {
                        $PolicyPaths = $UserConfig.SignedPolicyPath
                    }
                    else {
                        throw 'The currently saved value for SignedPolicyPath in user configurations is invalid.'
                    }
                }
                else {
                    throw "PolicyPaths parameter can't be empty and no valid configuration was found for SignedPolicyPath."
                }
            }
        }
        #endregion User-Configurations-Processing-Validation

        # Detecting if Debug switch is used, will do debugging actions based on that
        $PSBoundParameters.Debug.IsPresent ? ([System.Boolean]$Debug = $true) : ([System.Boolean]$Debug = $false) | Out-Null

        # argument tab auto-completion and ValidateSet for Policy names
        Class BasePolicyNamez : System.Management.Automation.IValidateSetValuesGenerator {
            [System.String[]] GetValidValues() {
                $BasePolicyNamez = ((&'C:\Windows\System32\CiTool.exe' -lp -json | ConvertFrom-Json).Policies | Where-Object -FilterScript { $_.IsSystemPolicy -ne 'True' } | Where-Object -FilterScript { $_.PolicyID -eq $_.BasePolicyID }).Friendlyname
                return [System.String[]]$BasePolicyNamez
            }
        }

        # argument tab auto-completion and ValidateSet for Fallbacks
        Class Fallbackz : System.Management.Automation.IValidateSetValuesGenerator {
            [System.String[]] GetValidValues() {
                $Fallbackz = ('Hash', 'FileName', 'SignedVersion', 'Publisher', 'FilePublisher', 'LeafCertificate', 'PcaCertificate', 'RootCertificate', 'WHQL', 'WHQLPublisher', 'WHQLFilePublisher', 'PFN', 'FilePath', 'None')
                return [System.String[]]$Fallbackz
            }
        }

        # argument tab auto-completion and ValidateSet for level
        Class Levelz : System.Management.Automation.IValidateSetValuesGenerator {
            [System.String[]] GetValidValues() {
                $Levelz = ('Hash', 'FileName', 'SignedVersion', 'Publisher', 'FilePublisher', 'LeafCertificate', 'PcaCertificate', 'RootCertificate', 'WHQL', 'WHQLPublisher', 'WHQLFilePublisher', 'PFN', 'FilePath', 'None')
                return [System.String[]]$Levelz
            }
        }

        #Re-Deploy Basepolicy in Enforced mode
        function Update-BasePolicyToEnforced {
            # Deploy Enforced mode CIP
            &'C:\Windows\System32\CiTool.exe' --update-policy ".\$PolicyID.cip" -json | Out-Null
            Write-ColorfulText -Color TeaGreen -InputText "`nThe Base policy with the following details has been Re-Signed and Re-Deployed in Enforced Mode:"
            Write-Output -InputObject "PolicyName = $PolicyName"
            Write-Output -InputObject "PolicyGUID = $PolicyID"
            # Remove Enforced Mode CIP
            Remove-Item -Path ".\$PolicyID.cip" -Force
        }
        [System.Object[]]$DriveLettersGlobalRootFix = Get-GlobalRootDrives
    }

    process {

        if ($AllowNewAppsAuditEvents) {

            # Change Code Integrity event logs size
            if ($AllowNewAppsAuditEvents -and $LogSize) { Set-LogSize -LogSize $LogSize }
            # Make sure there is no leftover from previous runs
            Remove-Item -Path '.\ProgramDir_ScanResults*.xml' -Force -ErrorAction SilentlyContinue
            Remove-Item -Path ".\SupplementalPolicy $SuppPolicyName.xml" -Force -ErrorAction SilentlyContinue
            # Get the current date so that instead of the entire event viewer logs, only audit logs created after running this module will be captured
            # The notice about variable being assigned and never used should be ignored - it's being dot-sourced from Resources file
            [System.DateTime]$Date = Get-Date
            # An empty array that holds the Policy XML files - This array will eventually be used to create the final Supplemental policy
            [System.Object[]]$PolicyXMLFilesArray = @()

            ################################### Initiate Live Audit Mode ###################################

            foreach ($PolicyPath in $PolicyPaths) {
                # Creating a copy of the original policy in Temp folder so that the original one will be unaffected
                $PolicyFileName = Split-Path $PolicyPath -Leaf
                Remove-Item -Path "$UserTempDirectoryPath\$PolicyFileName" -Force -ErrorAction SilentlyContinue # make sure no file with the same name already exists in Temp folder
                Copy-Item -Path $PolicyPath -Destination $UserTempDirectoryPath -Force
                $PolicyPath = "$UserTempDirectoryPath\$PolicyFileName"

                # Defining Base policy
                $xml = [System.Xml.XmlDocument](Get-Content -Path $PolicyPath)
                [System.String]$PolicyID = $xml.SiPolicy.PolicyID
                [System.String]$PolicyName = ($xml.SiPolicy.Settings.Setting | Where-Object -FilterScript { $_.provider -eq 'PolicyInfo' -and $_.valuename -eq 'Name' -and $_.key -eq 'Information' }).value.string

                # Remove any cip file if there is any
                Remove-Item -Path '.\*.cip' -Force -ErrorAction SilentlyContinue

                # Create CIP for Audit Mode
                Set-RuleOption -FilePath $PolicyPath -Option 6 -Delete # Remove Unsigned policy rule option
                Set-RuleOption -FilePath $PolicyPath -Option 3 # Add Audit mode policy rule option
                ConvertFrom-CIPolicy -XmlFilePath $PolicyPath -BinaryFilePath '.\AuditModeTemp.cip' | Out-Null

                # Create CIP for Enforced Mode
                Set-RuleOption -FilePath $PolicyPath -Option 6 -Delete # Remove Unsigned policy rule option
                Set-RuleOption -FilePath $PolicyPath -Option 3 -Delete # Remove Audit mode policy rule option
                ConvertFrom-CIPolicy -XmlFilePath $PolicyPath -BinaryFilePath '.\EnforcedModeTemp.cip' | Out-Null

                # Sign both CIPs
                '.\AuditModeTemp.cip', '.\EnforcedModeTemp.cip' | ForEach-Object -Process {
                    # Configure the parameter splat
                    $ProcessParams = @{
                        'ArgumentList' = 'sign', '/v' , '/n', "`"$CertCN`"", '/p7', '.', '/p7co', '1.3.6.1.4.1.311.79.1', '/fd', 'certHash', "`"$_`""
                        'FilePath'     = $SignToolPathFinal
                        'NoNewWindow'  = $true
                        'Wait'         = $true
                        'ErrorAction'  = 'Stop'
                    } # Only show the output of SignTool if Debug switch is used
                    if (!$Debug) { $ProcessParams['RedirectStandardOutput'] = 'NUL' }
                    # Sign the files with the specified cert
                    Start-Process @ProcessParams

                    # After creating signed .p7 files for each CIP, remove the old Unsigned ones
                    Remove-Item -Path $_ -Force
                }
                Rename-Item -Path '.\EnforcedModeTemp.cip.p7' -NewName '.\EnforcedMode.cip' -Force
                Rename-Item -Path '.\AuditModeTemp.cip.p7' -NewName '.\AuditMode.cip' -Force

                ################# Snap back guarantee #################
                Write-Verbose -Message 'Creating Enforced Mode SnapBack guarantee'

                $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
                $command = @"
CiTool --update-policy "$((Get-Location).Path)\$PolicyID.cip" -json; Remove-Item -Path "$((Get-Location).Path)\$PolicyID.cip" -Force
"@
                $command | Out-File -FilePath 'C:\EnforcedModeSnapBack.ps1' -Force
                New-ItemProperty -Path $registryPath -Name '*CIPolicySnapBack' -Value "powershell.exe -WindowStyle `"Hidden`" -ExecutionPolicy `"Bypass`" -Command `"& {&`"C:\EnforcedModeSnapBack.ps1`";Remove-Item -Path 'C:\EnforcedModeSnapBack.ps1' -Force}`"" -PropertyType String -Force | Out-Null

                # Deploy Audit mode CIP
                Write-Verbose -Message 'Deploying Audit mode CIP'
                Rename-Item -Path '.\AuditMode.cip' -NewName ".\$PolicyID.cip" -Force
                &'C:\Windows\System32\CiTool.exe' --update-policy ".\$PolicyID.cip" -json | Out-Null
                Write-ColorfulText -Color TeaGreen -InputText "`nThe Base policy with the following details has been Re-Signed and Re-Deployed in Audit Mode:"
                Write-Output -InputObject "PolicyName = $PolicyName"
                Write-Output -InputObject "PolicyGUID = $PolicyID"
                # Remove Audit Mode CIP
                Remove-Item -Path ".\$PolicyID.cip" -Force
                # Prepare Enforced Mode CIP for Deployment - waiting to be Re-deployed at the right time
                Rename-Item -Path '.\EnforcedMode.cip' -NewName ".\$PolicyID.cip" -Force

                # A Try-Catch-Finally block so that if any errors occur, the Base policy will be Re-deployed in enforced mode
                Try {
                    ################################### User Interaction ####################################
                    Write-ColorfulText -Color Pink -InputText "`nAudit mode deployed, start installing your programs now"
                    Write-ColorfulText -Color HotPink -InputText "When you've finished installing programs, Press Enter to start selecting program directories to scan`n"
                    Pause

                    # Store the program paths that user browses for in an array
                    [System.Object[]]$ProgramsPaths = @()
                    Write-Host -Object "`nSelect program directories to scan" -ForegroundColor Cyan
                    # Showing folder picker GUI to the user for folder path selection
                    do {
                        [System.Reflection.Assembly]::LoadWithPartialName('System.windows.forms') | Out-Null
                        $OBJ = New-Object System.Windows.Forms.FolderBrowserDialog
                        $OBJ.InitialDirectory = "$env:SystemDrive"
                        $OBJ.Description = $Description
                        $Spawn = New-Object System.Windows.Forms.Form -Property @{TopMost = $true }
                        $Show = $OBJ.ShowDialog($Spawn)
                        If ($Show -eq 'OK') { $ProgramsPaths += $OBJ.SelectedPath }
                        Else { break }
                    }
                    while ($true)

                    # Make sure User browsed for at least 1 directory
                    # Exit the operation if user didn't select any folder paths
                    if ($ProgramsPaths.count -eq 0) {
                        Write-Host -Object "`nNo program folder was selected, reverting the changes and quitting...`n" -ForegroundColor Red
                        # Causing break here to stop operation. Finally block will be triggered to Re-Deploy Base policy in Enforced mode
                        break
                    }

                    Write-Host -Object 'Here are the paths you selected:' -ForegroundColor Yellow
                    $ProgramsPaths | ForEach-Object -Process { $_ }

                    ################################### EventCapturing ################################

                    Write-Host -Object 'Scanning Windows Event logs and creating a policy file, please wait...' -ForegroundColor Cyan

                    # Extracting the array content from Get-AuditEventLogsProcessing function
                    $AuditEventLogsProcessingResults = Get-AuditEventLogsProcessing -Date $Date

                    # Only create policy for files that are available on the disk based on Event viewer logs but weren't in user-selected program path(s), if there are any
                    if ($AuditEventLogsProcessingResults.AvailableFilesPaths) {

                        # Using the function to find out which files are not in the user-selected path(s), if any, to only scan those
                        # this prevents duplicate rule creation and double file copying
                        $TestFilePathResults = (Test-FilePath -FilePath $AuditEventLogsProcessingResults.AvailableFilesPaths -DirectoryPath $ProgramsPaths).path | Select-Object -Unique

                        Write-Verbose -Message "$($TestFilePathResults.count) file(s) have been found in event viewer logs that don't exist in any of the folder paths you selected."

                        # Another check to make sure there were indeed files found in Event viewer logs but weren't in any of the user-selected path(s)
                        if ($TestFilePathResults) {
                            # Create a folder in Temp directory to copy the files that are not included in user-selected program path(s)
                            # but detected in Event viewer audit logs, scan that folder, and in the end delete it
                            New-Item -Path "$UserTempDirectoryPath\TemporaryScanFolderForEventViewerFiles" -ItemType Directory | Out-Null

                            Write-Verbose -Message "The following file(s) are being copied to the TEMP directory for scanning because they were found in event logs but didn't exist in any of the user-selected paths:"
                            $TestFilePathResults | ForEach-Object -Process {
                                Write-Verbose -Message "$_"
                                Copy-Item -Path $_ -Destination "$UserTempDirectoryPath\TemporaryScanFolderForEventViewerFiles\" -ErrorAction SilentlyContinue
                            }

                            # Create a policy XML file for available files on the disk

                            # Creating a hash table to dynamically add parameters based on user input and pass them to New-Cipolicy cmdlet
                            [System.Collections.Hashtable]$AvailableFilesOnDiskPolicyMakerHashTable = @{
                                FilePath               = '.\RulesForFilesNotInUserSelectedPaths.xml'
                                ScanPath               = "$UserTempDirectoryPath\TemporaryScanFolderForEventViewerFiles\"
                                Level                  = $Level
                                Fallback               = $Fallbacks
                                MultiplePolicyFormat   = $true
                                UserWriteablePaths     = $true
                                AllowFileNameFallbacks = $true
                            }
                            # Assess user input parameters and add the required parameters to the hash table
                            if ($SpecificFileNameLevel) { $AvailableFilesOnDiskPolicyMakerHashTable['SpecificFileNameLevel'] = $SpecificFileNameLevel }
                            if ($NoScript) { $AvailableFilesOnDiskPolicyMakerHashTable['NoScript'] = $true }
                            if (!$NoUserPEs) { $AvailableFilesOnDiskPolicyMakerHashTable['UserPEs'] = $true }

                            # Create the supplemental policy via parameter splatting
                            New-CIPolicy @AvailableFilesOnDiskPolicyMakerHashTable

                            # Add the policy XML file to the array that holds policy XML files
                            $PolicyXMLFilesArray += '.\RulesForFilesNotInUserSelectedPaths.xml'
                            # Delete the Temporary folder in the TEMP folder
                            Remove-Item -Recurse -Path "$UserTempDirectoryPath\TemporaryScanFolderForEventViewerFiles\" -Force
                        }
                    }

                    # Only create policy for files that are on longer available on the disk if there are any and
                    # if user chose to include deleted files in the final supplemental policy
                    if ($AuditEventLogsProcessingResults.DeletedFileHashes -and $IncludeDeletedFiles) {

                        Write-Verbose -Message "$($AuditEventLogsProcessingResults.DeletedFileHashes.count) file(s) have been found in event viewer logs that were run during Audit phase but are no longer on the disk, they are as follows:"
                        $AuditEventLogsProcessingResults.DeletedFileHashes | ForEach-Object -Process {
                            Write-Verbose -Message "$($_.'File Name')"
                        }

                        # Save the File Rules and File Rule Refs in the FileRulesAndFileRefs.txt in the current working directory for debugging purposes
                        (Get-FileRules -HashesArray $AuditEventLogsProcessingResults.DeletedFileHashes) + (Get-RuleRefs -HashesArray $AuditEventLogsProcessingResults.DeletedFileHashes) | Out-File -FilePath FileRulesAndFileRefs.txt -Force

                        # Put the Rules and RulesRefs in an empty policy file
                        New-EmptyPolicy -RulesContent (Get-FileRules -HashesArray $AuditEventLogsProcessingResults.DeletedFileHashes) -RuleRefsContent (Get-RuleRefs -HashesArray $AuditEventLogsProcessingResults.DeletedFileHashes) | Out-File -FilePath .\DeletedFileHashesEventsPolicy.xml -Force

                        # adding the policy file that consists of rules from audit even logs, to the array
                        $PolicyXMLFilesArray += '.\DeletedFileHashesEventsPolicy.xml'
                    }

                    ######################## Process Program Folders From User input #####################
                    for ($i = 0; $i -lt $ProgramsPaths.Count; $i++) {

                        # Creating a hash table to dynamically add parameters based on user input and pass them to New-Cipolicy cmdlet
                        [System.Collections.Hashtable]$UserInputProgramFoldersPolicyMakerHashTable = @{
                            FilePath               = ".\ProgramDir_ScanResults$($i).xml"
                            ScanPath               = $ProgramsPaths[$i]
                            Level                  = $Level
                            Fallback               = $Fallbacks
                            MultiplePolicyFormat   = $true
                            UserWriteablePaths     = $true
                            AllowFileNameFallbacks = $true
                        }
                        # Assess user input parameters and add the required parameters to the hash table
                        if ($SpecificFileNameLevel) { $UserInputProgramFoldersPolicyMakerHashTable['SpecificFileNameLevel'] = $SpecificFileNameLevel }
                        if ($NoScript) { $UserInputProgramFoldersPolicyMakerHashTable['NoScript'] = $true }
                        if (!$NoUserPEs) { $UserInputProgramFoldersPolicyMakerHashTable['UserPEs'] = $true }

                        # Create the supplemental policy via parameter splatting
                        New-CIPolicy @UserInputProgramFoldersPolicyMakerHashTable
                    }

                    # merge-cipolicy accept arrays - collecting all the policy files created by scanning user specified folders
                    $ProgramDir_ScanResults = Get-ChildItem -Path '.\' | Where-Object -FilterScript { $_.Name -like 'ProgramDir_ScanResults*.xml' }
                    foreach ($file in $ProgramDir_ScanResults) {
                        $PolicyXMLFilesArray += $file.FullName
                    }

                    #region Kernel-protected-files-automatic-detection-and-allow-rule-creation
                    # This part takes care of Kernel protected files such as the main executable of the games installed through Xbox app
                    # For these files, only Kernel can get their hashes, it passes them to event viewer and we take them from event viewer logs
                    # Any other attempts such as "Get-FileHash" or "Get-AuthenticodeSignature" fail and ConfigCI Module cmdlets totally ignore these files and do not create allow rules for them

                    # Finding the file(s) first and storing them in an array
                    [System.Object[]]$ExesWithNoHash = @()
                    # looping through each user-selected path(s)
                    foreach ($ProgramsPath in $ProgramsPaths) {
                        # Making sure the currently processing path has any .exe in it
                        $AnyAvailableExes = (Get-ChildItem -Recurse -Path $ProgramsPath -Filter '*.exe').FullName
                        # if any .exe was found then continue testing them
                        if ($AnyAvailableExes) {
                            $AnyAvailableExes | ForEach-Object -Process {
                                $CurrentExeWithNoHash = $_
                                try {
                                    # Testing each executable to find the protected ones
                                    Get-FileHash -Path $CurrentExeWithNoHash -ErrorAction Stop | Out-Null
                                }
                                # Making sure only the right file is captured by narrowing down the error type.
                                # E.g., when get-filehash can't get a file's hash because its open by another program, the exception is different: System.IO.IOException
                                catch [System.UnauthorizedAccessException] {
                                    $ExesWithNoHash += $CurrentExeWithNoHash
                                }
                            }
                        }
                    }
                    # Only proceed if any kernel protected file(s) were found in any of the user-selected directory path(s)
                    if ($ExesWithNoHash) {

                        Write-Verbose -Message "The following Kernel protected files detected, creating allow rules for them:`n"
                        $ExesWithNoHash | ForEach-Object -Process { Write-Verbose -Message "$_" }

                        [System.Management.Automation.ScriptBlock]$KernelProtectedHashesBlock = {
                            foreach ($event in Get-WinEvent -FilterHashtable @{LogName = 'Microsoft-Windows-CodeIntegrity/Operational'; ID = 3076 } -ErrorAction SilentlyContinue | Where-Object -FilterScript { $_.TimeCreated -ge $Date } ) {
                                $xml = [System.Xml.XmlDocument]$event.toxml()
                                $xml.event.eventdata.data |
                                ForEach-Object -Begin { $Hash = @{} } -Process { $hash[$_.name] = $_.'#text' } -End { [pscustomobject]$hash } |
                                ForEach-Object -Process {
                                    if ($_.'File Name' -match ($pattern = '\\Device\\HarddiskVolume(\d+)\\(.*)$')) {
                                        $hardDiskVolumeNumber = $Matches[1]
                                        $remainingPath = $Matches[2]
                                        $getletter = $DriveLettersGlobalRootFix | Where-Object -FilterScript { $_.devicepath -eq "\Device\HarddiskVolume$hardDiskVolumeNumber" }
                                        $usablePath = "$($getletter.DriveLetter)$remainingPath"
                                        $_.'File Name' = $_.'File Name' -replace $pattern, $usablePath
                                    } # Check if file is currently on the disk
                                    if (Test-Path -Path $_.'File Name') {
                                        # Check if the file exits in the $ExesWithNoHash array
                                        if ($ExesWithNoHash -contains $_.'File Name') {
                                            $_ | Select-Object FileVersion, 'File Name', PolicyGUID, 'SHA256 Hash', 'SHA256 Flat Hash', 'SHA1 Hash', 'SHA1 Flat Hash'
                                        }
                                    }
                                }
                            }
                        }
                        $KernelProtectedHashesBlockResults = Invoke-Command -ScriptBlock $KernelProtectedHashesBlock

                        # Only proceed further if any hashes belonging to the detected kernel protected files were found in Event viewer
                        # If none is found then skip this part, because user didn't run those files/programs when audit mode was turned on in base policy, so no hash was found in audit logs
                        if ($KernelProtectedHashesBlockResults) {

                            # Save the File Rules and File Rule Refs in the FileRulesAndFileRefs.txt in the current working directory for debugging purposes
                            (Get-FileRules -HashesArray $KernelProtectedHashesBlockResults) + (Get-RuleRefs -HashesArray $KernelProtectedHashesBlockResults) | Out-File -FilePath KernelProtectedFiles.txt -Force

                            # Put the Rules and RulesRefs in an empty policy file
                            New-EmptyPolicy -RulesContent (Get-FileRules -HashesArray $KernelProtectedHashesBlockResults) -RuleRefsContent (Get-RuleRefs -HashesArray $KernelProtectedHashesBlockResults) | Out-File -FilePath .\KernelProtectedFiles.xml -Force

                            # adding the policy file  to the array of xml files
                            $PolicyXMLFilesArray += '.\KernelProtectedFiles.xml'
                        }
                        else {
                            Write-Warning -Message "The following Kernel protected files detected, but no hash was found for them in Event viewer logs.`nThis means you didn't run those files/programs when Audit mode was turned on.`n"
                            $ExesWithNoHash | ForEach-Object -Process { Write-Warning -Message "$_" }
                        }
                    }
                    #endregion Kernel-protected-files-automatic-detection-and-allow-rule-creation

                    Write-Verbose -Message 'The following policy xml files are going to be merged into the final Supplemental policy and be deployed on the system:'
                    $PolicyXMLFilesArray | ForEach-Object -Process { Write-Verbose -Message "$_" }

                    # Merge all of the policy XML files in the array into the final Supplemental policy
                    Merge-CIPolicy -PolicyPaths $PolicyXMLFilesArray -OutputFilePath ".\SupplementalPolicy $SuppPolicyName.xml" | Out-Null

                    # Delete these extra files unless user uses -Debug parameter
                    if (-NOT $Debug) {
                        Remove-Item -Path '.\FileRulesAndFileRefs.txt', '.\DeletedFileHashesEventsPolicy.xml' -Force -ErrorAction SilentlyContinue
                        Remove-Item -Path '.\ProgramDir_ScanResults*.xml', '.\RulesForFilesNotInUserSelectedPaths.xml' -Force -ErrorAction SilentlyContinue
                        Remove-Item -Path '.\KernelProtectedFiles.txt', '.\KernelProtectedFiles.xml' -Force -ErrorAction SilentlyContinue
                    }
                }
                # Unlike AllowNewApps parameter, AllowNewAppsAuditEvents parameter performs Event viewer scanning and kernel protected files detection
                # So the base policy enforced mode snap back can't happen any sooner than this point
                catch {
                    $_
                    $_.CategoryInfo
                    $_.ErrorDetails
                    $_.Exception
                    $_.FullyQualifiedErrorId
                    $_.InvocationInfo
                    $_.PipelineIterationInfo
                    $_.PSMessageDetails
                    $_.ScriptStackTrace
                    $_.TargetObject
                }
                finally {
                    # Deploy Enforced mode CIP
                    Write-Verbose -Message 'Finally Block Running'
                    Update-BasePolicyToEnforced
                    # Enforced Mode Snapback removal after base policy has already been successfully re-enforced
                    Write-Verbose -Message 'Removing the SnapBack guarantee because the base policy has been successfully re-enforced'
                    Remove-Item -Path 'C:\EnforcedModeSnapBack.ps1' -Force
                    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Name '*CIPolicySnapBack' -Force
                }

                #################### Supplemental-policy-processing-and-deployment ############################

                $SuppPolicyPath = ".\SupplementalPolicy $SuppPolicyName.xml"
                $SuppPolicyID = Set-CIPolicyIdInfo -FilePath $SuppPolicyPath -PolicyName "$SuppPolicyName - $(Get-Date -Format 'MM-dd-yyyy')" -ResetPolicyID -BasePolicyToSupplementPath $PolicyPath
                $SuppPolicyID = $SuppPolicyID.Substring(11)
                Add-SignerRule -FilePath $SuppPolicyPath -CertificatePath $CertPath -Update -User -Kernel

                # Make sure policy rule options that don't belong to a Supplemental policy don't exit
                @(0, 1, 2, 3, 4, 6, 8, 9, 10, 11, 12, 15, 16, 17, 19, 20) | ForEach-Object -Process { Set-RuleOption -FilePath $SuppPolicyPath -Option $_ -Delete }

                Set-HVCIOptions -Strict -FilePath $SuppPolicyPath
                Set-CIPolicyVersion -FilePath $SuppPolicyPath -Version '1.0.0.0'

                ConvertFrom-CIPolicy -XmlFilePath $SuppPolicyPath -BinaryFilePath "$SuppPolicyID.cip" | Out-Null

                # Configure the parameter splat
                $ProcessParams = @{
                    'ArgumentList' = 'sign', '/v' , '/n', "`"$CertCN`"", '/p7', '.', '/p7co', '1.3.6.1.4.1.311.79.1', '/fd', 'certHash', ".\$SuppPolicyID.cip"
                    'FilePath'     = $SignToolPathFinal
                    'NoNewWindow'  = $true
                    'Wait'         = $true
                    'ErrorAction'  = 'Stop'
                } # Only show the output of SignTool if Debug switch is used
                if (!$Debug) { $ProcessParams['RedirectStandardOutput'] = 'NUL' }
                # Sign the files with the specified cert
                Start-Process @ProcessParams

                Remove-Item -Path ".\$SuppPolicyID.cip" -Force
                Rename-Item -Path "$SuppPolicyID.cip.p7" -NewName "$SuppPolicyID.cip" -Force
                &'C:\Windows\System32\CiTool.exe' --update-policy ".\$SuppPolicyID.cip" -json | Out-Null
                Write-ColorfulText -Color TeaGreen -InputText "`nSupplemental policy with the following details has been Signed and Deployed in Enforced Mode:"
                Write-Output -InputObject "SupplementalPolicyName = $SuppPolicyName"
                Write-Output -InputObject "SupplementalPolicyGUID = $SuppPolicyID"
                Remove-Item -Path ".\$SuppPolicyID.cip" -Force
                Remove-Item -Path $PolicyPath -Force # Remove the policy xml file in Temp folder we created earlier
            }
        }

        if ($AllowNewApps) {

            # remove any possible files from previous runs
            Remove-Item -Path '.\ProgramDir_ScanResults*.xml' -Force -ErrorAction SilentlyContinue
            Remove-Item -Path ".\SupplementalPolicy $SuppPolicyName.xml" -Force -ErrorAction SilentlyContinue
            # An empty array that holds the Policy XML files - This array will eventually be used to create the final Supplemental policy
            [System.Object[]]$PolicyXMLFilesArray = @()

            #Initiate Live Audit Mode

            foreach ($PolicyPath in $PolicyPaths) {
                # Creating a copy of the original policy in Temp folder so that the original one will be unaffected
                $PolicyFileName = Split-Path $PolicyPath -Leaf
                Remove-Item -Path "$UserTempDirectoryPath\$PolicyFileName" -Force -ErrorAction SilentlyContinue # make sure no file with the same name already exists in Temp folder
                Copy-Item -Path $PolicyPath -Destination $UserTempDirectoryPath -Force
                $PolicyPath = "$UserTempDirectoryPath\$PolicyFileName"

                # Defining Base policy
                $xml = [System.Xml.XmlDocument](Get-Content -Path $PolicyPath)
                [System.String]$PolicyID = $xml.SiPolicy.PolicyID
                [System.String]$PolicyName = ($xml.SiPolicy.Settings.Setting | Where-Object -FilterScript { $_.provider -eq 'PolicyInfo' -and $_.valuename -eq 'Name' -and $_.key -eq 'Information' }).value.string

                # Remove any cip file if there is any
                Remove-Item -Path '.\*.cip' -Force -ErrorAction SilentlyContinue

                # Create CIP for Audit Mode
                Set-RuleOption -FilePath $PolicyPath -Option 6 -Delete # Remove Unsigned policy rule option
                Set-RuleOption -FilePath $PolicyPath -Option 3 # Add Audit mode policy rule option
                ConvertFrom-CIPolicy -XmlFilePath $PolicyPath -BinaryFilePath '.\AuditModeTemp.cip' | Out-Null

                # Create CIP for Enforced Mode
                Set-RuleOption -FilePath $PolicyPath -Option 6 -Delete # Remove Unsigned policy rule option
                Set-RuleOption -FilePath $PolicyPath -Option 3 -Delete # Remove Audit mode policy rule option
                ConvertFrom-CIPolicy -XmlFilePath $PolicyPath -BinaryFilePath '.\EnforcedModeTemp.cip' | Out-Null

                # Sign both CIPs
                '.\AuditModeTemp.cip', '.\EnforcedModeTemp.cip' | ForEach-Object -Process {
                    # Configure the parameter splat
                    $ProcessParams = @{
                        'ArgumentList' = 'sign', '/v' , '/n', "`"$CertCN`"", '/p7', '.', '/p7co', '1.3.6.1.4.1.311.79.1', '/fd', 'certHash', "`"$_`""
                        'FilePath'     = $SignToolPathFinal
                        'NoNewWindow'  = $true
                        'Wait'         = $true
                        'ErrorAction'  = 'Stop'
                    } # Only show the output of SignTool if Debug switch is used
                    if (!$Debug) { $ProcessParams['RedirectStandardOutput'] = 'NUL' }
                    # Sign the files with the specified cert
                    Start-Process @ProcessParams

                    # After creating signed .p7 files for each CIP, remove the old Unsigned ones
                    Remove-Item -Path $_ -Force
                }
                Rename-Item -Path '.\EnforcedModeTemp.cip.p7' -NewName '.\EnforcedMode.cip' -Force
                Rename-Item -Path '.\AuditModeTemp.cip.p7' -NewName '.\AuditMode.cip' -Force

                ################# Snap back guarantee #################
                Write-Verbose -Message 'Creating Enforced Mode SnapBack guarantee'

                $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
                $command = @"
CiTool --update-policy "$((Get-Location).Path)\$PolicyID.cip" -json; Remove-Item -Path "$((Get-Location).Path)\$PolicyID.cip" -Force
"@
                $command | Out-File -FilePath 'C:\EnforcedModeSnapBack.ps1' -Force
                New-ItemProperty -Path $registryPath -Name '*CIPolicySnapBack' -Value "powershell.exe -WindowStyle `"Hidden`" -ExecutionPolicy `"Bypass`" -Command `"& {&`"C:\EnforcedModeSnapBack.ps1`";Remove-Item -Path 'C:\EnforcedModeSnapBack.ps1' -Force}`"" -PropertyType String -Force | Out-Null

                # Deploy Audit mode CIP
                Write-Verbose -Message 'Deploying Audit mode CIP'
                Rename-Item -Path '.\AuditMode.cip' -NewName ".\$PolicyID.cip" -Force
                &'C:\Windows\System32\CiTool.exe' --update-policy ".\$PolicyID.cip" -json | Out-Null
                Write-ColorfulText -Color TeaGreen -InputText "`nThe Base policy with the following details has been Re-Signed and Re-Deployed in Audit Mode:"
                Write-Output -InputObject "PolicyName = $PolicyName"
                Write-Output -InputObject "PolicyGUID = $PolicyID"
                # Remove Audit Mode CIP
                Remove-Item -Path ".\$PolicyID.cip" -Force
                # Prepare Enforced Mode CIP for Deployment - waiting to be Re-deployed at the right time
                Rename-Item -Path '.\EnforcedMode.cip' -NewName ".\$PolicyID.cip" -Force

                # A Try-Catch-Finally block so that if any errors occur, the Base policy will be Re-deployed in enforced mode
                Try {
                    ################################### User Interaction ####################################
                    Write-ColorfulText -Color Pink -InputText "`nAudit mode deployed, start installing your programs now"
                    Write-ColorfulText -Color HotPink -InputText "When you've finished installing programs, Press Enter to start selecting program directories to scan`n"
                    Pause

                    # Store the program paths that user browses for in an array
                    [System.Object[]]$ProgramsPaths = @()
                    Write-Host -Object "`nSelect program directories to scan`n" -ForegroundColor Cyan
                    # Showing folder picker GUI to the user for folder path selection
                    do {
                        [System.Reflection.Assembly]::LoadWithPartialName('System.windows.forms') | Out-Null
                        $OBJ = New-Object System.Windows.Forms.FolderBrowserDialog
                        $OBJ.InitialDirectory = "$env:SystemDrive"
                        $OBJ.Description = $Description
                        $Spawn = New-Object System.Windows.Forms.Form -Property @{TopMost = $true }
                        $Show = $OBJ.ShowDialog($Spawn)
                        If ($Show -eq 'OK') { $ProgramsPaths += $OBJ.SelectedPath }
                        Else { break }
                    }
                    while ($true)

                    # Make sure User browsed for at least 1 directory
                    # Exit the operation if user didn't select any folder paths
                    if ($ProgramsPaths.count -eq 0) {
                        Write-Host -Object "`nNo program folder was selected, reverting the changes and quitting...`n" -ForegroundColor Red
                        # Causing break here to stop operation. Finally block will be triggered to Re-Deploy Base policy in Enforced mode
                        break
                    }
                }
                catch {
                    # Show any extra info about any possible error that might've occurred
                    $_
                    $_.CategoryInfo
                    $_.ErrorDetails
                    $_.Exception
                    $_.FullyQualifiedErrorId
                    $_.InvocationInfo
                    $_.PipelineIterationInfo
                    $_.PSMessageDetails
                    $_.ScriptStackTrace
                    $_.TargetObject
                }
                finally {
                    # Deploy Enforced mode CIP
                    Write-Verbose -Message 'Finally Block Running'
                    Update-BasePolicyToEnforced
                    # Enforced Mode Snapback removal after base policy has already been successfully re-enforced
                    Write-Verbose -Message 'Removing the SnapBack guarantee because the base policy has been successfully re-enforced'
                    Remove-Item -Path 'C:\EnforcedModeSnapBack.ps1' -Force
                    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Name '*CIPolicySnapBack' -Force
                }

                Write-Host -Object "`nHere are the paths you selected:" -ForegroundColor Yellow
                $ProgramsPaths | ForEach-Object -Process { $_ }

                #Process Program Folders From User input

                # Scan each of the folder paths that user selected
                for ($i = 0; $i -lt $ProgramsPaths.Count; $i++) {

                    # Creating a hash table to dynamically add parameters based on user input and pass them to New-Cipolicy cmdlet
                    [System.Collections.Hashtable]$UserInputProgramFoldersPolicyMakerHashTable = @{
                        FilePath               = ".\ProgramDir_ScanResults$($i).xml"
                        ScanPath               = $ProgramsPaths[$i]
                        Level                  = $Level
                        Fallback               = $Fallbacks
                        MultiplePolicyFormat   = $true
                        UserWriteablePaths     = $true
                        AllowFileNameFallbacks = $true
                    }
                    # Assess user input parameters and add the required parameters to the hash table
                    if ($SpecificFileNameLevel) { $UserInputProgramFoldersPolicyMakerHashTable['SpecificFileNameLevel'] = $SpecificFileNameLevel }
                    if ($NoScript) { $UserInputProgramFoldersPolicyMakerHashTable['NoScript'] = $true }
                    if (!$NoUserPEs) { $UserInputProgramFoldersPolicyMakerHashTable['UserPEs'] = $true }

                    # Create the supplemental policy via parameter splatting
                    New-CIPolicy @UserInputProgramFoldersPolicyMakerHashTable
                }

                # merge-cipolicy accept arrays - collecting all the policy files created by scanning user specified folders
                $ProgramDir_ScanResults = Get-ChildItem -Path '.\' | Where-Object -FilterScript { $_.Name -like 'ProgramDir_ScanResults*.xml' }
                foreach ($file in $ProgramDir_ScanResults) {
                    $PolicyXMLFilesArray += $file.FullName
                }

                Write-Verbose -Message 'The following policy xml files are going to be merged into the final Supplemental policy and be deployed on the system:'
                $PolicyXMLFilesArray | ForEach-Object -Process { Write-Verbose -Message "$_" }

                # Merge all of the policy XML files in the array into the final Supplemental policy
                Merge-CIPolicy -PolicyPaths $PolicyXMLFilesArray -OutputFilePath ".\SupplementalPolicy $SuppPolicyName.xml" | Out-Null

                Remove-Item -Path '.\ProgramDir_ScanResults*.xml' -Force

                #################### Supplemental-policy-processing-and-deployment ############################

                $SuppPolicyPath = ".\SupplementalPolicy $SuppPolicyName.xml"
                $SuppPolicyID = Set-CIPolicyIdInfo -FilePath $SuppPolicyPath -PolicyName "$SuppPolicyName - $(Get-Date -Format 'MM-dd-yyyy')" -ResetPolicyID -BasePolicyToSupplementPath $PolicyPath
                $SuppPolicyID = $SuppPolicyID.Substring(11)
                Add-SignerRule -FilePath $SuppPolicyPath -CertificatePath $CertPath -Update -User -Kernel

                # Make sure policy rule options that don't belong to a Supplemental policy don't exit
                @(0, 1, 2, 3, 4, 6, 8, 9, 10, 11, 12, 15, 16, 17, 19, 20) | ForEach-Object -Process { Set-RuleOption -FilePath $SuppPolicyPath -Option $_ -Delete }

                Set-HVCIOptions -Strict -FilePath $SuppPolicyPath
                Set-CIPolicyVersion -FilePath $SuppPolicyPath -Version '1.0.0.0'

                ConvertFrom-CIPolicy -XmlFilePath $SuppPolicyPath -BinaryFilePath "$SuppPolicyID.cip" | Out-Null

                # Configure the parameter splat
                $ProcessParams = @{
                    'ArgumentList' = 'sign', '/v' , '/n', "`"$CertCN`"", '/p7', '.', '/p7co', '1.3.6.1.4.1.311.79.1', '/fd', 'certHash', ".\$SuppPolicyID.cip"
                    'FilePath'     = $SignToolPathFinal
                    'NoNewWindow'  = $true
                    'Wait'         = $true
                    'ErrorAction'  = 'Stop'
                } # Only show the output of SignTool if Debug switch is used
                if (!$Debug) { $ProcessParams['RedirectStandardOutput'] = 'NUL' }
                # Sign the files with the specified cert
                Start-Process @ProcessParams

                Remove-Item -Path ".\$SuppPolicyID.cip" -Force
                Rename-Item -Path "$SuppPolicyID.cip.p7" -NewName "$SuppPolicyID.cip" -Force
                &'C:\Windows\System32\CiTool.exe' --update-policy ".\$SuppPolicyID.cip" -json | Out-Null
                Write-ColorfulText -Color TeaGreen -InputText "`nSupplemental policy with the following details has been Signed and Deployed in Enforced Mode:"
                Write-Output -InputObject "SupplementalPolicyName = $SuppPolicyName"
                Write-Output -InputObject "SupplementalPolicyGUID = $SuppPolicyID"
                Remove-Item -Path ".\$SuppPolicyID.cip" -Force
                Remove-Item -Path $PolicyPath -Force # Remove the policy xml file in Temp folder we created earlier
            }
        }

        if ($MergeSupplementalPolicies) {
            foreach ($PolicyPath in $PolicyPaths) {
                ############ Input policy verification prior to doing anything ############
                foreach ($SuppPolicyPath in $SuppPolicyPaths) {
                    $Supplementalxml = [System.Xml.XmlDocument](Get-Content -Path $SuppPolicyPath)
                    $SupplementalPolicyID = $Supplementalxml.SiPolicy.PolicyID
                    $SupplementalPolicyType = $Supplementalxml.SiPolicy.PolicyType
                    $DeployedPoliciesIDs = (&'C:\Windows\System32\CiTool.exe' -lp -json | ConvertFrom-Json).Policies.PolicyID | ForEach-Object -Process { return "{$_}" }
                    # Check the type of the user selected Supplemental policy XML files to make sure they are indeed Supplemental policies
                    if ($SupplementalPolicyType -ne 'Supplemental Policy') {
                        Write-Error -Message "The Selected XML file with GUID $SupplementalPolicyID isn't a Supplemental Policy."
                    }
                    # Check to make sure the user selected Supplemental policy XML files are deployed on the system
                    if ($DeployedPoliciesIDs -notcontains $SupplementalPolicyID) {
                        Write-Error -Message "The Selected Supplemental XML file with GUID $SupplementalPolicyID isn't deployed on the system."
                    }
                }
                # Perform the merge
                Merge-CIPolicy -PolicyPaths $SuppPolicyPaths -OutputFilePath "$SuppPolicyName.xml" | Out-Null
                # Delete the deployed Supplemental policies that user selected from the system because we're going to deploy the new merged policy that contains all of them
                foreach ($SuppPolicyPath in $SuppPolicyPaths) {
                    $Supplementalxml = [System.Xml.XmlDocument](Get-Content -Path $SuppPolicyPath)
                    $SupplementalPolicyID = $Supplementalxml.SiPolicy.PolicyID
                    &'C:\Windows\System32\CiTool.exe' --remove-policy $SupplementalPolicyID -json | Out-Null
                    # remove the old policy files unless user chose to keep them
                    if (!$KeepOldSupplementalPolicies) { Remove-Item -Path $SuppPolicyPath -Force }
                }
                # Prepare the final merged Supplemental policy for deployment
                $SuppPolicyID = Set-CIPolicyIdInfo -FilePath "$SuppPolicyName.xml" -ResetPolicyID -PolicyName "$SuppPolicyName - $(Get-Date -Format 'MM-dd-yyyy')" -BasePolicyToSupplementPath $PolicyPath
                $SuppPolicyID = $SuppPolicyID.Substring(11)
                Add-SignerRule -FilePath "$SuppPolicyName.xml" -CertificatePath $CertPath -Update -User -Kernel
                Set-HVCIOptions -Strict -FilePath "$SuppPolicyName.xml"
                Set-RuleOption -FilePath "$SuppPolicyName.xml" -Option 6 -Delete
                ConvertFrom-CIPolicy -XmlFilePath "$SuppPolicyName.xml" -BinaryFilePath "$SuppPolicyID.cip" | Out-Null

                # Configure the parameter splat
                $ProcessParams = @{
                    'ArgumentList' = 'sign', '/v' , '/n', "`"$CertCN`"", '/p7', '.', '/p7co', '1.3.6.1.4.1.311.79.1', '/fd', 'certHash', ".\$SuppPolicyID.cip"
                    'FilePath'     = $SignToolPathFinal
                    'NoNewWindow'  = $true
                    'Wait'         = $true
                    'ErrorAction'  = 'Stop'
                } # Only show the output of SignTool if Debug switch is used
                if (!$Debug) { $ProcessParams['RedirectStandardOutput'] = 'NUL' }
                # Sign the files with the specified cert
                Start-Process @ProcessParams

                Remove-Item -Path ".\$SuppPolicyID.cip" -Force
                Rename-Item -Path "$SuppPolicyID.cip.p7" -NewName "$SuppPolicyID.cip" -Force
                &'C:\Windows\System32\CiTool.exe' --update-policy "$SuppPolicyID.cip" -json | Out-Null
                Write-ColorfulText -Color TeaGreen -InputText "`nThe Signed Supplemental policy $SuppPolicyName has been deployed on the system, replacing the old ones.`nSystem Restart Not immediately needed but eventually required to finish the removal of previous individual Supplemental policies."
                Remove-Item -Path "$SuppPolicyID.cip" -Force
            }
        }

        if ($UpdateBasePolicy) {
            # First get the Microsoft recommended block rules
            Get-BlockRulesMeta | Out-Null

            switch ($NewBasePolicyType) {
                'AllowMicrosoft_Plus_Block_Rules' {
                    Copy-Item -Path 'C:\Windows\schemas\CodeIntegrity\ExamplePolicies\AllowMicrosoft.xml' -Destination '.\AllowMicrosoft.xml'
                    Merge-CIPolicy -PolicyPaths .\AllowMicrosoft.xml, '.\Microsoft recommended block rules.xml' -OutputFilePath .\BasePolicy.xml | Out-Null
                    Set-CIPolicyIdInfo -FilePath .\BasePolicy.xml -PolicyName "Allow Microsoft Plus Block Rules refreshed On $(Get-Date -Format 'MM-dd-yyyy')"
                    @(0, 2, 5, 11, 12, 16, 17, 19, 20) | ForEach-Object -Process { Set-RuleOption -FilePath .\BasePolicy.xml -Option $_ }
                    @(3, 4, 6, 9, 10, 13, 18) | ForEach-Object -Process { Set-RuleOption -FilePath .\BasePolicy.xml -Option $_ -Delete }
                }
                'Lightly_Managed_system_Policy' {
                    Copy-Item -Path 'C:\Windows\schemas\CodeIntegrity\ExamplePolicies\AllowMicrosoft.xml' -Destination '.\AllowMicrosoft.xml'
                    Merge-CIPolicy -PolicyPaths .\AllowMicrosoft.xml, '.\Microsoft recommended block rules.xml' -OutputFilePath .\BasePolicy.xml | Out-Null
                    Set-CIPolicyIdInfo -FilePath .\BasePolicy.xml -PolicyName "Signed And Reputable policy refreshed on $(Get-Date -Format 'MM-dd-yyyy')"
                    @(0, 2, 5, 11, 12, 14, 15, 16, 17, 19, 20) | ForEach-Object -Process { Set-RuleOption -FilePath .\BasePolicy.xml -Option $_ }
                    @(3, 4, 6, 9, 10, 13, 18) | ForEach-Object -Process { Set-RuleOption -FilePath .\BasePolicy.xml -Option $_ -Delete }
                    # Configure required services for ISG authorization
                    Start-Process -FilePath 'C:\Windows\System32\appidtel.exe' -ArgumentList 'start' -Wait -NoNewWindow
                    Start-Process -FilePath 'C:\Windows\System32\sc.exe' -ArgumentList 'config', 'appidsvc', 'start= auto' -Wait -NoNewWindow
                }
                'DefaultWindows_WithBlockRules' {
                    Copy-Item -Path 'C:\Windows\schemas\CodeIntegrity\ExamplePolicies\DefaultWindows_Enforced.xml' -Destination '.\DefaultWindows_Enforced.xml'

                    # Allowing SignTool to be able to run after Default Windows base policy is deployed
                    Write-ColorfulText -Color TeaGreen -InputText "`nCreating allow rules for SignTool.exe in the DefaultWindows base policy so you can continue using it after deploying the DefaultWindows base policy."
                    New-Item -Path "$UserTempDirectoryPath\TemporarySignToolFile" -ItemType Directory -Force | Out-Null
                    Copy-Item -Path $SignToolPathFinal -Destination "$UserTempDirectoryPath\TemporarySignToolFile" -Force
                    New-CIPolicy -ScanPath "$UserTempDirectoryPath\TemporarySignToolFile" -Level FilePublisher -Fallback Hash -UserPEs -UserWriteablePaths -MultiplePolicyFormat -AllowFileNameFallbacks -FilePath .\SignTool.xml
                    # Delete the Temporary folder in the TEMP folder
                    if (!$Debug) { Remove-Item -Recurse -Path "$UserTempDirectoryPath\TemporarySignToolFile" -Force }

                    # Scan PowerShell core directory and add them to the Default Windows base policy so that the module can be used after it's been deployed
                    if (Test-Path -Path 'C:\Program Files\PowerShell') {
                        Write-ColorfulText -Color HotPink -InputText "`nCreating allow rules for PowerShell in the DefaultWindows base policy so you can continue using this module after deploying it."
                        New-CIPolicy -ScanPath 'C:\Program Files\PowerShell' -Level FilePublisher -NoScript -Fallback Hash -UserPEs -UserWriteablePaths -MultiplePolicyFormat -AllowFileNameFallbacks -FilePath .\AllowPowerShell.xml
                        Merge-CIPolicy -PolicyPaths .\DefaultWindows_Enforced.xml, .\AllowPowerShell.xml, .\SignTool.xml, '.\Microsoft recommended block rules.xml' -OutputFilePath .\BasePolicy.xml | Out-Null
                    }
                    else {
                        Merge-CIPolicy -PolicyPaths .\DefaultWindows_Enforced.xml, .\SignTool.xml, '.\Microsoft recommended block rules.xml' -OutputFilePath .\BasePolicy.xml | Out-Null
                    }
                    Set-CIPolicyIdInfo -FilePath .\BasePolicy.xml -PolicyName "Default Windows Plus Block Rules refreshed On $(Get-Date -Format 'MM-dd-yyyy')"
                    @(0, 2, 5, 11, 12, 16, 17, 19, 20) | ForEach-Object -Process { Set-RuleOption -FilePath .\BasePolicy.xml -Option $_ }
                    @(3, 4, 6, 9, 10, 13, 18) | ForEach-Object -Process { Set-RuleOption -FilePath .\BasePolicy.xml -Option $_ -Delete }
                }
            }

            if ($UpdateBasePolicy -and $RequireEVSigners) { Set-RuleOption -FilePath .\BasePolicy.xml -Option 8 }

            # Remove the extra files create during module operation that are no longer necessary
            if (!$Debug) {
                Remove-Item -Path '.\AllowPowerShell.xml', '.\SignTool.xml', '.\AllowMicrosoft.xml', '.\DefaultWindows_Enforced.xml' -Force -ErrorAction SilentlyContinue
                Remove-Item -Path '.\Microsoft recommended block rules.xml' -Force
            }

            # Get the policy ID of the currently deployed base policy based on the policy name that user selected
            $CurrentID = ((&'C:\Windows\System32\CiTool.exe' -lp -json | ConvertFrom-Json).Policies | Where-Object -FilterScript { $_.IsSystemPolicy -ne 'True' } | Where-Object -FilterScript { $_.Friendlyname -eq $CurrentBasePolicyName }).BasePolicyID
            $CurrentID = "{$CurrentID}"
            Remove-Item -Path ".\$CurrentID.cip" -Force -ErrorAction SilentlyContinue

            [System.Xml.XmlDocument]$xml = Get-Content -Path '.\BasePolicy.xml'
            $xml.SiPolicy.PolicyID = $CurrentID
            $xml.SiPolicy.BasePolicyID = $CurrentID
            $xml.Save('.\BasePolicy.xml')

            Add-SignerRule -FilePath .\BasePolicy.xml -CertificatePath $CertPath -Update -User -Kernel -Supplemental

            Set-CIPolicyVersion -FilePath .\BasePolicy.xml -Version '1.0.0.1'
            Set-HVCIOptions -Strict -FilePath .\BasePolicy.xml

            ConvertFrom-CIPolicy -XmlFilePath '.\BasePolicy.xml' -BinaryFilePath "$CurrentID.cip" | Out-Null

            # Configure the parameter splat
            $ProcessParams = @{
                'ArgumentList' = 'sign', '/v' , '/n', "`"$CertCN`"", '/p7', '.', '/p7co', '1.3.6.1.4.1.311.79.1', '/fd', 'certHash', ".\$CurrentID.cip"
                'FilePath'     = $SignToolPathFinal
                'NoNewWindow'  = $true
                'Wait'         = $true
                'ErrorAction'  = 'Stop'
            } # Only show the output of SignTool if Debug switch is used
            if (!$Debug) { $ProcessParams['RedirectStandardOutput'] = 'NUL' }
            # Sign the files with the specified cert
            Start-Process @ProcessParams

            Remove-Item -Path ".\$CurrentID.cip" -Force
            Rename-Item -Path "$CurrentID.cip.p7" -NewName "$CurrentID.cip" -Force
            # Deploy the new base policy with the same GUID on the system
            &'C:\Windows\System32\CiTool.exe' --update-policy "$CurrentID.cip" -json | Out-Null
            # Keep the new base policy XML file that was just deployed, in the current directory, so user can keep it for later
            $PolicyFiles = @{
                'AllowMicrosoft_Plus_Block_Rules' = 'AllowMicrosoftPlusBlockRules.xml'
                'Lightly_Managed_system_Policy'   = 'SignedAndReputable.xml'
                'DefaultWindows_WithBlockRules'   = 'DefaultWindowsPlusBlockRules.xml'
            }
            Remove-Item -Path ".\$CurrentID.cip" -Force
            Remove-Item -Path $PolicyFiles[$NewBasePolicyType] -Force -ErrorAction SilentlyContinue
            Rename-Item -Path '.\BasePolicy.xml' -NewName $PolicyFiles[$NewBasePolicyType]
            Write-ColorfulText -Color Pink -InputText "Base Policy has been successfully updated to $NewBasePolicyType"
            Write-ColorfulText -Color Lavender -InputText 'Keep in mind that your previous policy path saved in User Configurations is no longer valid as you just changed your Base policy.'
        }
    }

    <#
.SYNOPSIS
    Edits Signed WDAC policies deployed on the system (Windows Defender Application Control)

.LINK
    https://github.com/HotCakeX/Harden-Windows-Security/wiki/Edit-SignedWDACConfig

.DESCRIPTION
    Using official Microsoft methods, Edits Signed WDAC policies deployed on the system (Windows Defender Application Control)

.COMPONENT
    Windows Defender Application Control, ConfigCI PowerShell module

.FUNCTIONALITY
    Using official Microsoft methods, Edits Signed WDAC policies deployed on the system (Windows Defender Application Control)

.PARAMETER AllowNewAppsAuditEvents
    Rebootlessly install new apps/programs when Signed policy is already deployed, use audit events to capture installation files, scan their directories for new Supplemental policy, Sign and deploy thew Supplemental policy.

.PARAMETER AllowNewApps
    Rebootlessly install new apps/programs when Signed policy is already deployed, scan their directories for new Supplemental policy, Sign and deploy thew Supplemental policy.

.PARAMETER MergeSupplementalPolicies
    Merges multiple Signed deployed supplemental policies into 1 single supplemental policy, removes the old ones, deploys the new one. System restart needed to take effect.

.PARAMETER UpdateBasePolicy
    It can rebootlessly change the type of the deployed signed base policy. It can update the recommended block rules and/or change policy rule options in the deployed base policy.

.PARAMETER SkipVersionCheck
    Can be used with any parameter to bypass the online version check - only to be used in rare cases
    It is used by the entire Cmdlet.

.PARAMETER LogSize
    The log size to set for Code Integrity/Operational event logs
    The accepted values are between 1024 KB and 18014398509481983 KB
    The max range is the maximum allowed log size by Windows Event viewer

.PARAMETER CertCN
    Common name of the certificate used to sign the deployed Signed WDAC policy
    It is Used by the entire Cmdlet

.PARAMETER Level
    The level that determines how the selected folder will be scanned.
    The default value for it is FilePublisher.

.PARAMETER Fallbacks
    The fallback level(s) that determine how the selected folder will be scanned.
    The default value for it is Hash.

#>
}

# Importing argument completer ScriptBlocks
. "$ModuleRootPath\Resources\ArgumentCompleters.ps1"
Register-ArgumentCompleter -CommandName 'Edit-SignedWDACConfig' -ParameterName 'CertCN' -ScriptBlock $ArgumentCompleterCertificateCN
Register-ArgumentCompleter -CommandName 'Edit-SignedWDACConfig' -ParameterName 'CertPath' -ScriptBlock $ArgumentCompleterCerFilePathsPicker
Register-ArgumentCompleter -CommandName 'Edit-SignedWDACConfig' -ParameterName 'SignToolPath' -ScriptBlock $ArgumentCompleterExeFilePathsPicker
Register-ArgumentCompleter -CommandName 'Edit-SignedWDACConfig' -ParameterName 'PolicyPaths' -ScriptBlock $ArgumentCompleterPolicyPathsBasePoliciesOnly
Register-ArgumentCompleter -CommandName 'Edit-SignedWDACConfig' -ParameterName 'SuppPolicyPaths' -ScriptBlock $ArgumentCompleterPolicyPathsSupplementalPoliciesOnly
