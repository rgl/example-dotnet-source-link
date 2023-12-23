#!/usr/bin/pwsh

param(
    [Parameter(Mandatory = $true)]
    [string]$stage
)

#
# enable strict mode and fail the job when there is an unhandled exception.

Set-StrictMode -Version Latest
$FormatEnumerationLimit = -1
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    "ERROR: $_" | Write-Host
    ($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$', 'ERROR: $1' | Write-Host
    ($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$', 'ERROR EXCEPTION: $1' | Write-Host
    Exit 1
}

#
# define helper functions.
function exec([ScriptBlock]$externalCommand, [string]$stderrPrefix = '', [int[]]$successExitCodes = @(0)) {
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        &$externalCommand 2>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                "$stderrPrefix$_"
            }
            else {
                "$_"
            }
        }
        if ($LASTEXITCODE -notin $successExitCodes) {
            throw "$externalCommand failed with exit code $LASTEXITCODE"
        }
        if ($LASTEXITCODE -ne 0) {
            # force $LASTEXITCODE to 0 and $? to $true. these are normally checked
            # by the CI system to known whether the command was successful or not.
            $global:LASTEXITCODE = 0
            $? | Out-Null
        }
    }
    finally {
        $ErrorActionPreference = $eap
    }
}

function Invoke-StageBuild {
    # restore the tools.
    exec {
        dotnet tool restore
    }
    # build the library.
    Push-Location ExampleLibrary
    exec {
        dotnet build -v n -c Release
    }
    exec {
        dotnet pack -v n -c Release --no-build -p:PackageVersion=0.0.3 --output .
    }
    Pop-Location

    # build the application.
    Push-Location ExampleApplication
    exec {
        dotnet build -v n -c Release
    }
    Pop-Location
}

function Invoke-StageTest {
    Push-Location ExampleApplication
    exec {
        dotnet tool run sourcelink print-urls bin/Release/net8.0/ExampleApplication.dll
    }
    exec {
        dotnet tool run sourcelink print-json bin/Release/net8.0/ExampleApplication.dll | ConvertFrom-Json | ConvertTo-Json -Depth 100
    }
    exec {
        dotnet tool run sourcelink print-documents bin/Release/net8.0/ExampleApplication.dll
    }
    # NB -532462766 (on Windows) or 134 (on Ubuntu) are the expected successful
    #    exit codes.
    exec -successExitCodes -532462766,134 {
        dotnet run -v n -c Release --no-build
    }
    Pop-Location
}

# publish the package to the GitLab project repository.
# see https://docs.gitlab.com/ee/user/packages/nuget_repository/index.html#publish-a-nuget-package-by-using-cicd
function Invoke-StagePublish {
    [xml]$nuGetConfig = Get-Content NuGet.Config
    $packageSource = $nuGetConfig.CreateElement('add')
    $packageSource.SetAttribute('key', 'gitlab')
    $packageSource.SetAttribute('value', "$env:CI_SERVER_URL/api/v4/projects/$env:CI_PROJECT_ID/packages/nuget/index.json")
    $packageSource.SetAttribute('protocolVersion', '3')
    $nuGetConfig.configuration.packageSources.AppendChild($packageSource) | Out-Null
    $packageSourceCredentials = $nuGetConfig.CreateElement('packageSourceCredentials')
    $packageSourceCredentials.InnerXml = @'
  <gitlab>
    <add key="Username" value="gitlab-ci-token" />
    <add key="ClearTextPassword" value="" />
  </gitlab>
'@
    $password = $packageSourceCredentials.SelectSingleNode('gitlab/add[@key="ClearTextPassword"]')
    $password.value = $env:CI_JOB_TOKEN
    $nuGetConfig.configuration.AppendChild($packageSourceCredentials) | Out-Null
    $nuGetConfig.Save("$PWD/NuGet.Config")
    exec {
        dotnet nuget push `
            (Resolve-Path ExampleLibrary/ExampleLibrary.*.nupkg) `
                --source gitlab
    }
}

Invoke-Expression "Invoke-Stage$([System.Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($stage))"