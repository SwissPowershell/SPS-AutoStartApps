Enum SPSStartupItemTrigger {
    Logon
    Logoff
    Startup
    Shutdown
    Idle
    Time
    Event
}
Enum SPSStartupItemType {
    Run
    RunOnce
    StartMenu
    Service
    Task
}
Enum SPSStartupItemAppType {
    MSIX
    Native
}
Enum SPSStartupItemBitness {
    x86
    x64
}
enum SPSStartupItemScope {
    LocalMachine
    CurrentUser
}
Enum SPSStartupItemStatus {
    Enabled
    Disabled
}
Class SPSStartupItemCommand {
    [String] ${Description}
    [String] ${Command}
    [String] ${Arguments}
    [String] ${Version}
    SPSStartupItemCommand() {}
    SPSStartupItemCommand([String] $FullCommandLine) {
        # Split the command line into command and arguments
        # Define if the command is between quotes to split it correctly
        $IsQuoted = $FullCommandLine.StartsWith('"')
        if ($IsQuoted) {
            $this.Command = ($FullCommandLine.Substring(1, $FullCommandLine.IndexOf('"', 1) - 1)).Trim()
            $this.Arguments = try{($FullCommandLine.Substring($FullCommandLine.IndexOf('"', 1) + 2)).Trim()} catch {''}
        } else {
            if ($FullCommandLine -match '\.exe\s.*$') {
                $this.Command = ($FullCommandLine.Split(' ')[0]).Trim()
                $this.Arguments = try {($FullCommandLine.Split(' ')[1]).Trim()} catch {''}
            }else{
                $this.Command = $FullCommandLine
            }
        }
        $this.__getDetails()
    }
    SPSStartupItemCommand([String] $Command, [String] $Arguments) {
        $this.Command = $Command
        $this.Arguments = $Arguments
        $this.__getDetails()
    }
    [String] ToString() {
        if ($this.Arguments -eq '') {
            return $this.Command
        } else {
            return "$($this.Command) $($this.Arguments)"
        }
    }
    [void] __getDetails() {
        Try {
            $Item = Get-Item -Path $this.Command
            $this.Description = $Item.VersionInfo.FileDescription
            $this.Version = $Item.VersionInfo.FileVersion
        }Catch{}
    }
    
}
Class SPSAutoStartItem{
    [SPSStartupItemType]    ${Type}                     # the type of the item can be Run, RunOnce, StartMenu, Service or Task
    [SPSStartupItemScope]   ${Scope}                    # the scope of the item can be LocalMachine or CurrentUser
    [SPSStartupItemTrigger] ${Trigger}                  # the trigger of the item can be Logon, Logoff, Startup, Shutdown, Idle, Time or Event
    [String]                ${Name}                     # the name of the item
    [String]                ${Description}              # the description
    [String]                ${AppUserModelID}           # the AppUserModelID of the item if it apply
    [SPSStartupItemCommand] ${CommandLine}              # the command line of the item
    [String]                ${Owner}                    # the owner of the item
    [String]                ${RunAs} = 'CurrentUser'    # CurrentUser, LocalSystem, LocalService, NetworkService or a specific user      
    [Boolean]               ${ReadOnly}                 # if the item is read only
    [Boolean]               ${InStartupCmd}             # if the item is in the startup command list
    [Boolean]               ${IsApproved}               # if the command is approved start
    [SPSStartupItemAppType] ${AppType}                  # the type of the application can be MSIX or Native
    [SPSStartupItemBitness] ${Bitness}                  # the bitness of the item can be x86 or x64
    [SPSStartupItemStatus]  ${Status}                   # the status of the item can be Enabled or Disabled
    Hidden [Object]         ${__item}                   # the original item object
    SPSAutoStartItem() {}
    static [System.Collections.Generic.List[SPSAutoStartItem]] GetAll() {
        Write-Verbose 'method GetAll() called'
        # Retrieve all items in all possible locations
        [System.Collections.Generic.List[SPSAutoStartItem]] $Items = @()
        $RunUser = Get-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue | Add-Member -PassThru -MemberType NoteProperty -Name Path -Value 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        $RunMachineX64 = Get-Item -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue | Add-Member -PassThru -MemberType NoteProperty -Name Path -Value 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
        $RunMachineX86 = Get-Item -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue | Add-Member -PassThru -MemberType NoteProperty -Name Path -Value 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run'
        $RunOnceUser = Get-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -ErrorAction SilentlyContinue | Add-Member -PassThru -MemberType NoteProperty -Name Path -Value 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
        $RunOnceMachineX64 = Get-Item -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -ErrorAction SilentlyContinue | Add-Member -PassThru -MemberType NoteProperty -Name Path -Value 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
        $RunOnceMachineX86 = Get-Item -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce' -ErrorAction SilentlyContinue | Add-Member -PassThru -MemberType NoteProperty -Name Path -Value 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce'
        $ApprovedRun = Get-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run','HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property
        $StartupFolderUser = Get-ChildItem -Path "$($env:APPDATA)\Microsoft\Windows\Start Menu\Programs\Startup" -ErrorAction SilentlyContinue
        $StartupFolderMachine = Get-ChildItem -Path "$($env:ALLUSERSPROFILE)\Microsoft\Windows\Start Menu\Programs\Startup" -ErrorAction SilentlyContinue
        $TaskScheduler = Get-ScheduledTask -ErrorAction SilentlyContinue -Verbose:$False
        $Services = Get-Service -ErrorAction SilentlyContinue -Verbose 'SilentlyContinue'
        $StartupCommands = Get-CimInstance -ClassName win32_startupcommand -ErrorAction SilentlyContinue
        $StartApps = Get-StartApps -ErrorAction SilentlyContinue -Verbose 'SilentlyContinue'
        $AppXPackages = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue -Verbose 'SilentlyContinue'
        # define if the current user is administrator to know if the HKLM keys are accessible, this will impact all the "machine" object ReadOnly settings
        $IsAdmin = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')

        # Create an object per item in each list
        # Handle registry keys
        $RunUser.Property | ForEach-Object {
            $Item = [SPSAutoStartItem]::New()
            $Item.Type = [SPSStartupItemType]::Run
            $Item.Name = $_
            $Item.Trigger = [SPSStartupItemTrigger]::Logon
            $Item.CommandLine = [SPSStartupItemCommand]::New($RunUser.GetValue($_))
            $item.Description = $Item.CommandLine.Description
            $Item.Owner = Get-ACL $RunUser.Path | Select-Object -ExpandProperty Owner
            $Item.RunAs = 'CurrentUser'
            $Item.ReadOnly = $false
            $Item.AppType = [SPSStartupItemAppType]::Native
            $Item.Scope = [SPSStartupItemScope]::CurrentUser
            $Item.Bitness = [SPSStartupItemBitness]::x64
            $Item.Status = [SPSStartupItemStatus]::Enabled
            $Item.InStartupCmd = ($StartupCommands | Where-Object { $_.Caption -eq $Item.Name} | Select-Object -ExpandProperty Command -First 1) -notlike $null
            $Item.IsApproved = $_ -in $ApprovedRun
            $Items.Add($Item)
        }
        $RunOnceUser.Property | ForEach-Object {
            $Item = [SPSAutoStartItem]::New()
            $Item.Type = [SPSStartupItemType]::RunOnce
            $Item.Name = $_
            $Item.Trigger = [SPSStartupItemTrigger]::Logon
            $Item.CommandLine = [SPSStartupItemCommand]::New($RunOnceUser.GetValue($_))
            $item.Description = $Item.CommandLine.Description
            $Item.Owner = Get-ACL $RunOnceUser.Path | Select-Object -ExpandProperty Owner
            $Item.RunAs = 'CurrentUser'
            $Item.ReadOnly = $false
            $Item.AppType = [SPSStartupItemAppType]::Native
            $Item.Scope = [SPSStartupItemScope]::CurrentUser
            $Item.Bitness = [SPSStartupItemBitness]::x64
            $Item.Status = [SPSStartupItemStatus]::Enabled
            $Item.InStartupCmd = ($StartupCommands | Where-Object { $_.Caption -eq $Item.Name} | Select-Object -ExpandProperty Command -First 1) -notlike $null
            $Item.IsApproved = $_ -in $ApprovedRun
            $Items.Add($Item)
        }
        $RunMachineX64.Property | ForEach-Object {
            $Item = [SPSAutoStartItem]::New()
            $Item.Type = [SPSStartupItemType]::Run
            $Item.Name = $_
            $Item.Trigger = [SPSStartupItemTrigger]::Logon
            $Item.CommandLine = [SPSStartupItemCommand]::New($RunMachineX64.GetValue($_))
            $item.Description = $Item.CommandLine.Description
            $Item.Owner = Get-ACL $RunMachineX64.Path | Select-Object -ExpandProperty Owner
            $Item.RunAs = 'CurrentUser'
            $Item.ReadOnly = $false
            $Item.AppType = [SPSStartupItemAppType]::Native
            $Item.Scope = [SPSStartupItemScope]::LocalMachine
            $Item.Bitness = [SPSStartupItemBitness]::x64
            $Item.Status = [SPSStartupItemStatus]::Enabled
            $Item.InStartupCmd = ($StartupCommands | Where-Object { $_.Caption -eq $Item.Name} | Select-Object -ExpandProperty Command -First 1) -notlike $null
            $Item.IsApproved = $_ -in $ApprovedRun
            $Items.Add($Item)
        }
        $RunMachineX86.Property | ForEach-Object {
            $Item = [SPSAutoStartItem]::New()
            $Item.Type = [SPSStartupItemType]::Run
            $Item.Name = $_
            $Item.Trigger = [SPSStartupItemTrigger]::Logon
            $Item.CommandLine = [SPSStartupItemCommand]::New($RunMachineX86.GetValue($_))
            $item.Description = $Item.CommandLine.Description
            $Item.Owner = Get-ACL $RunMachineX86.Path | Select-Object -ExpandProperty Owner
            $Item.RunAs = 'CurrentUser'
            $Item.ReadOnly = $false
            $Item.AppType = [SPSStartupItemAppType]::Native
            $Item.Scope = [SPSStartupItemScope]::LocalMachine
            $Item.Bitness = [SPSStartupItemBitness]::x86
            $Item.Status = [SPSStartupItemStatus]::Enabled
            $Item.InStartupCmd = ($StartupCommands | Where-Object { $_.Caption -eq $Item.Name} | Select-Object -ExpandProperty Command -First 1) -notlike $null
            $Item.IsApproved = $_ -in $ApprovedRun
            $Items.Add($Item)
        }
        $RunOnceMachineX64.Property | ForEach-Object {
            $Item = [SPSAutoStartItem]::New()
            $Item.Type = [SPSStartupItemType]::RunOnce
            $Item.Name = $_
            $Item.Trigger = [SPSStartupItemTrigger]::Logon
            $Item.CommandLine = [SPSStartupItemCommand]::New($RunOnceMachineX64.GetValue($_))
            $item.Description = $Item.CommandLine.Description
            $Item.Owner = Get-ACL $RunOnceMachineX64.Path | Select-Object -ExpandProperty Owner
            $Item.RunAs = 'CurrentUser'
            $Item.ReadOnly = $false
            $Item.AppType = [SPSStartupItemAppType]::Native
            $Item.Scope = [SPSStartupItemScope]::LocalMachine
            $Item.Bitness = [SPSStartupItemBitness]::x64
            $Item.Status = [SPSStartupItemStatus]::Enabled
            $Item.InStartupCmd = ($StartupCommands | Where-Object { $_.Caption -eq $Item.Name} | Select-Object -ExpandProperty Command -First 1) -notlike $null
            $Item.IsApproved = $_ -in $ApprovedRun
            $Items.Add($Item)
        }
        $RunOnceMachineX86.Property | ForEach-Object {
            $Item = [SPSAutoStartItem]::New()
            $Item.Type = [SPSStartupItemType]::RunOnce
            $Item.Name = $_
            $Item.Trigger = [SPSStartupItemTrigger]::Logon
            $Item.CommandLine = [SPSStartupItemCommand]::New($RunOnceMachineX86.GetValue($_))
            $item.Description = $Item.CommandLine.Description
            $Item.Owner = Get-ACL $RunOnceMachineX86.Path | Select-Object -ExpandProperty Owner
            $Item.RunAs = 'CurrentUser'
            $Item.ReadOnly = $false
            $Item.AppType = [SPSStartupItemAppType]::Native
            $Item.Scope = [SPSStartupItemScope]::LocalMachine
            $Item.Bitness = [SPSStartupItemBitness]::x86
            $Item.Status = [SPSStartupItemStatus]::Enabled
            $Item.InStartupCmd = ($StartupCommands | Where-Object { $_.Caption -eq $Item.Name} | Select-Object -ExpandProperty Command -First 1) -notlike $null
            $Item.IsApproved = $_ -in $ApprovedRun
            $Items.Add($Item)
        }
        Return $Items
    }
}
Function Get-SPSAutoStartApps {
    [CmdletBinding()]
    Param()
    BEGIN {
        Write-Verbose "Starting $($MyInvocation.MyCommand.Name)"
    }
    PROCESS {
        Write-Verbose "Processing $($MyInvocation.MyCommand.Name)"
    }
    END {
        Write-Verbose "Ending $($MyInvocation.MyCommand.Name)"
    }
}



#region Expose the types and enums to the session as type accelerators. (thanks to Gael Colas for the heads up on this approach)
$ExportableTypes =@([SPSAutoStartItem])
# Get the internal TypeAccelerators class to use its static methods.
$TypeAcceleratorsClass = [PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
# Ensure none of the types would clobber an existing type accelerator.
# If a type accelerator with the same name exists, throw an exception.
$ExistingTypeAccelerators = $TypeAcceleratorsClass::Get
ForEach ($Type in $ExportableTypes) {
    if ($Type.FullName -in $ExistingTypeAccelerators.Keys) {
        $Message = @(
            "Unable to register type accelerator '$($Type.FullName)'"
            'Accelerator already exists.'
        ) -join ' - '
        Write-Warning -Message $Message
    }
}
# Add type accelerators for every exportable type.
ForEach ($Type in $ExportableTypes) {
    $TypeAcceleratorsClass::Add($Type.FullName, $Type) | out-null
}
# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    ForEach ($Type in $ExportableTypes) {
        $TypeAcceleratorsClass::Remove($Type.FullName) | out-null
    }
}.GetNewClosure() | out-null
#endregion Export the types to the session as type accelerators.