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
    [String] ${Command}
    [String] ${Arguments}
    SPSStartupItemCommand() {}
    SPSStartupItemCommand([String] $FullCommandLine) {
        # Split the command line into command and arguments
        # Define if the command is between quotes to split it correctly
        $IsQuoted = $FullCommandLine.StartsWith('"')
        if ($IsQuoted) {
            $this.Command = ($FullCommandLine.Substring(1, $FullCommandLine.IndexOf('"', 1) - 1)).Trim()
            $this.Arguments = try{($FullCommandLine.Substring($FullCommandLine.IndexOf('"', 1) + 2)).Trim()} catch {''}
        } else {
            $this.Command = ($FullCommandLine.Split(' ')[0]).Trim()
            $this.Arguments = try {($FullCommandLine.Split(' ')[1]).Trim()} catch {''}
        }
    }
    SPSStartupItemCommand([String] $Command, [String] $Arguments) {
        $this.Command = $Command
        $this.Arguments = $Arguments
    }
    [String] ToString() {
        if ($this.Arguments -eq '') {
            return $this.Command
        } else {
            return "$($this.Command) $($this.Arguments)"
        }
    }
    
}
Class SPSAutoStartItem{
    [SPSStartupItemType]    ${Type}                     # the type of the item can be Run, RunOnce, StartMenu, Service or Task
    [String]                ${Name}                     # the name of the item
    [SPSStartupItemTrigger] ${Trigger}                  # the trigger of the item can be Logon, Logoff, Startup, Shutdown, Idle, Time or Event
    [String]                ${AppUserModelID}           # the AppUserModelID of the item if it apply
    [SPSStartupItemCommand] ${CommandLine}              # the command line of the item
    [String]                ${Owner}                    # the owner of the item
    [String]                ${RunAs} = 'CurrentUser'    # CurrentUser, LocalSystem, LocalService, NetworkService or a specific user      
    [Boolean]               ${ReadOnly}                 # if the item is read only
    [SPSStartupItemAppType] ${AppType}                  # the type of the application can be MSIX or Native
    [SPSStartupItemScope]   ${Scope}                    # the scope of the item can be LocalMachine or CurrentUser
    [SPSStartupItemBitness] ${Bitness}                  # the bitness of the item can be x86 or x64
    [SPSStartupItemStatus]  ${Status}                   # the status of the item can be Enabled or Disabled
    Hidden [Object]         ${__item}                   # the original item object
    SPSAutoStartItem() {}
    static [void] GetAll() {
        Write-Verbose 'method GetAll() called'
        # Retrieve all items in all possible locations
        $RunUser = Get-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue | Add-Member -PassThru -MemberType NoteProperty -Name Path -Value 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        $RunMachineX64 = Get-Item -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue | Add-Member -PassThru -MemberType NoteProperty -Name Path -Value 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
        $RunMachineX86 = Get-Item -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue | Add-Member -PassThru -MemberType NoteProperty -Name Path -Value 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run'
        $RunOnceUser = Get-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -ErrorAction SilentlyContinue | Add-Member -PassThru -MemberType NoteProperty -Name Path -Value 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
        $RunOnceMachineX64 = Get-Item -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -ErrorAction SilentlyContinue | Add-Member -PassThru -MemberType NoteProperty -Name Path -Value 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
        $RunOnceMachineX86 = Get-Item -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce' -ErrorAction SilentlyContinue | Add-Member -PassThru -MemberType NoteProperty -Name Path -Value 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce'
        $ApprovedRunUser = Get-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' -ErrorAction SilentlyContinue | Add-Member -PassThru -MemberType NoteProperty -Name Path -Value 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        $ApprovedRunMachineX64 = Get-Item -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' -ErrorAction SilentlyContinue | Add-Member -PassThru -MemberType NoteProperty -Name Path -Value 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        $ApprovedRunMachineX86 = Get-Item -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' -ErrorAction SilentlyContinue | Add-Member -PassThru -MemberType NoteProperty -Name Path -Value 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        $StartupFolderUser = Get-ChildItem -Path "$($env:APPDATA)\Microsoft\Windows\Start Menu\Programs\Startup" -ErrorAction SilentlyContinue
        $StartupFolderMachine = Get-ChildItem -Path "$($env:ALLUSERSPROFILE)\Microsoft\Windows\Start Menu\Programs\Startup" -ErrorAction SilentlyContinue
        $TaskScheduler = Get-ScheduledTask
        $Services = Get-Service -ErrorAction SilentlyContinue
        $StartupCommands = Get-CimInstance -ClassName win32_startupcommand -ErrorAction SilentlyContinue
        $StartApps = Get-StartApps -ErrorAction SilentlyContinue
        # define if the current user is administrator to know if the HKLM keys are accessible, this will impact all the "machine" object ReadOnly settings
        $IsAdmin = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')
        # Create an object per item in each list
        
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