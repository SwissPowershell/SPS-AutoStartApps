Function Get-SPSStartupApps {
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