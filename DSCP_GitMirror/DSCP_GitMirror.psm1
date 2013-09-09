function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Destination
	)

	#Write-Verbose "Use this cmdlet to deliver information about command processing."

	#Write-Debug "Use this cmdlet to write debug information while troubleshooting."


	<#
	$returnValue = @{
		Destination = [System.String]
		GitPath = [System.String]
		Branch = [System.String]
	}

	$returnValue
	#>
    
    
}

function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Destination,

        [Parameter(Mandatory = $true)]
		[System.String]
        [ValidateScript({Test-Path $_})]
		$GitPath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Url,

		[System.String]
		$Branch="master"
	)
    Write-Verbose "Test-TargetResource called with the following parameters:"
    Write-Verbose "Destination:`t$Destination"
    Write-Verbose "GitPath:`t$GitPath"
    Write-Verbose "URL:`t$URL"
    Write-Verbose "Branch:`t$branch"
    $gitexe = Get-GitExe $GitPath
	if ((Test-git -gitexe $gitexe -url $url -destination $destination) -eq "True") {
        $true
    }
    else {
        $false
    }
}

function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Destination,

        [Parameter(Mandatory = $true)]
		[System.String]
        [ValidateScript({Test-Path $_})]
		$GitPath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Url,

		[System.String]
		$Branch="master"
	)	
    Write-Verbose "Set-TargetResource called with the following parameters:"
    Write-Verbose "Destination:`t$Destination"
    Write-Verbose "GitPath:`t$GitPath"
    Write-Verbose "URL:`t$URL"
    Write-Verbose "Branch:`t$branch"
    $gitexe = Get-GitExe $GitPath

    if ($gitexe) {
        switch (Test-git -gitexe $gitexe -url $url -destination $destination) {
            "Clone" {
                Clone-Git -gitexe $gitexe -url $url -destination $Destination -branch $branch
                break
            }
            "NewURL" {
                RemoveClone-Git -gitexe $gitexe -url $url -destination $Destination -branch $Branch
                break
            }
            "Branch" {
                RemoveClone-Git -gitexe $gitexe -url $url -destination $Destination -branch $Branch
                break
            }
            "Updated"{
                # TODO - add beter logic here - perhaps a reset to head of origin/branch
                RemoveClone-Git -gitexe $gitexe -url $url -destination $Destination -branch $Branch
                break
            }
        }
    }
    Write-Verbose "End of Set-TargetResource"
}

function Get-GitExe {
    param(
        [Parameter(Mandatory=$false, Position=0)]
        [string]$path=""
    )
    $newpath = $path

    if ($path) {        
        Write-Verbose "Get-GitExe Called with $path"
        # Check whether the supplied path includes git.exe
        if (!((Split-Path $path -Leaf) -eq 'git.exe')) {
            Write-Verbose "Path to git does not include git.exe - assuming it's a directory"
            $newpath = Join-Path $path "git.exe"
            # check whether git.exe is located in the path provided
            if (!(test-path $newpath)) {             
                write-verbose "$newpath not found"
                $newpath = join-path $path "bin\git.exe"
                # check whether git is located in a bin directory below the path provided
                if (!(test-path $newpath)) {
                    Write-verbose "$newpath not found"
                    $newpath = ""
                }                
            }
        }
    }
    <# This code is not working.  Leaving b/c I'd like to have it eventually work with the path
    For some reason the path var is set and works in a remote session, but not through DSC - even when it is set through DSC
    # If it was not found above, check if it is available on the system in the PATH
    if (!($newpath)) {
        $newpath = (get-command git.exe -ErrorAction SilentlyContinue).FileVersionInfo.filename
    }
    #>

    if ($newpath) {
        Write-Verbose "Git found here: $newpath"
        $newpath
    }
    else {
        Write-Verbose "Git.exe not found"
    }

}

function RemoveClone-Git {
    param(
        [Parameter(Mandatory=$true)]
        [string] $gitexe,
        [Parameter(Mandatory=$true)]
        [string] $url,
        [Parameter(Mandatory=$true)]
        [string] $destination,
        [Parameter(Mandatory=$true)]
        [string] $branch
    )
    cd ..
    Write-Verbose "Deleting $destination"
    rm -Recurse $Destination -Force
    Clone-Git -gitexe $gitexe -url $url -destination $Destination -branch $Branch
}

function Clone-Git {
    param(
        [Parameter(Mandatory=$true)]
        [string] $gitexe,
        [Parameter(Mandatory=$true)]
        [string] $url,
        [Parameter(Mandatory=$true)]
        [string] $destination,
        [Parameter(Mandatory=$true)]
        [string] $branch
    )
    Write-verbose "Cloning $branch from $url into $destination"
    try {
        ((& $gitexe "clone", "-b", $branch, "--single-branch", $url, $destination) 2>&1|%{$_}) -join "`r`n" |Write-Verbose
    } catch [exception] {
        Write-Verbose "Exception caught:"
        Write-Verbose $_
    }
}

function Test-Git {
    param(
        [Parameter(Mandatory=$true)]
        [string] $gitexe,
        [Parameter(Mandatory=$true)]
        [string] $url,
        [Parameter(Mandatory=$true)]
        [string] $destination
    )
    # Helper function shared by test-targetresource and set-targetresource.  
    # Ideally this should be moved to only test-targetresource and pass the change required to Set-targetresource, but global vars weren't working on first try
    
    # This function returns a command that needs to be run.  If it is okay it returns True as a string.

    Write-Verbose "Test-Git"
    Write-Verbose "Calling function: $((Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name)"

    if (!(Test-Path $destination)) {
        # If the path does not exist, clone
        "Clone"
    } else {
        Write-verbose "Changing directory to $destination"
        cd $Destination
        Write-verbose "Validating that the url is the remote for origin"
        $existingurl = (& $gitexe remote, "-v") 2>&1 |?{$_ -match '^origin\s+(.+)\s+\(fetch\)$'} |%{$matches[1]}
        Write-Verbose "Existing url is $existingurl"
        # Check whether the URL in the local git for origin fetch is the same as the configured url, if not, it will delete and reclone
        if ($url -ne $existingurl) {
            if ($existingurl) {
                Write-verbose "URL mismatch"
                "NewURL"
            }
            else {
                Write-Verbose "ERROR: There is an existing directory with no git repository.  In order to prevent accidental deletion, ensure that $destination does not exist prior to synching the first time"
                throw "There is an existing directory with no git repository.  In order to prevent accidental deletion, ensure that $destination does not exist prior to synching the first time"
            }
        }
        else {
            $status = (& $gitexe status)
            $status[0] -match 'On branch (.+)$' |out-null
            Write-Verbose "Existing branch is $($matches[1])"
            # Check whether the branch in local git is the same as the configured branch
            if ($matches[1] -ne $branch) {
                Write-Verbose "Branch mismatch"
                "Branch"
            } else {
                write-verbose "Status: $($status[1])"
                if ($status[1] -notmatch 'nothing to commit, working directory clean') {
                    Write-Verbose "Changes detected between origin and local"
                    "Updated"
                }
                else {
                    "True"
                }
            }
        }
    }
}