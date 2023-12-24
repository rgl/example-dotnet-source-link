#!/usr/bin/pwsh

param(
    [Parameter(Mandatory = $true)]
    [string]$stage
)

# library and application versions to set.
# NB these versions have the semver syntax. e.g.:
#       1.2.3
#       1.2.3.4-rc0
#       1.2.3.4-rc.0
# NB they will set two PE properties, e.g.:
#       FileVersion:    1.2.3.0
#       ProductVersion: 1.2.3+9706f44682c796d3172d810cc5077cc8f2f19674
#    the "+<revision>" is automatically set to the last commit revision.
# NB they will set the nuspec nuget package version, e.g.:
#       <version>1.2.3</version>
$libVersion = '0.0.3'
$appVersion = '0.0.1'

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

function Invoke-StageClean {
    # clean the build.
    $('ExampleLibrary', 'ExampleApplication') | ForEach-Object {
        Write-Host "cleaning $_..."
        Push-Location $_
        $('bin', 'obj') | ForEach-Object {
            if (Test-Path $_) {
                Remove-Item -Force -Recurse $_
            }
        }
        Pop-Location
    }
    # clean the packages.
    Write-Host 'cleaning packages...'
    if (Test-Path packages) {
        Remove-Item -Force -Recurse packages
    }
    # clean the ExampleLibrary nuget packages cache.
    Invoke-StageCleanNugetCache
}

function Invoke-StageCleanNugetCache {
    # clean the ExampleLibrary nuget packages cache.
    Write-Host 'cleaning ExampleLibrary nuget packages cache...'
    dotnet nuget locals global-packages --force-english-output --list `
        | ForEach-Object {
            # e.g. global-packages: /home/vagrant/.nuget/packages/
            if ($_ -match '^global-packages: (?<path>.+)') {
                $cachePath = Join-Path $Matches['path'] examplelibrary
                if (Test-Path $cachePath) {
                    Remove-Item -Force -Recurse $cachePath
                }
            }
        }
}

function Invoke-StageBuild {
    # clean the ExampleLibrary nuget packages cache.
    Invoke-StageCleanNugetCache

    # create the packages directory.
    New-Item -ItemType Directory -Force packages | Out-Null

    # restore the tools.
    exec {
        Write-Host 'dotnet tool restore...'
        dotnet tool restore
    }

    # build the library.
    Push-Location ExampleLibrary
    exec {
        Write-Host 'dotnet build ExampleLibrary...'
        dotnet build -v n -c Release "-p:Version=$libVersion"
    }
    exec {
        Write-Host 'sbom-tool ExampleLibrary...'
        if (Test-Path bin/Release/net8.0/_manifest) {
            Remove-Item -Recurse -Force bin/Release/net8.0/_manifest
        }
        New-Item -ItemType Directory bin/Release/net8.0/_manifest | Out-Null
        dotnet tool run sbom-tool generate `
            -BuildDropPath bin/Release/net8.0 `
            -ManifestDirPath bin/Release/net8.0/_manifest `
            -BuildComponentPath . `
            -PackageSupplier ExampleCompany `
            -NamespaceUriBase https://sbom.example.com `
            -PackageName ExampleLibrary `
            -PackageVersion $libVersion `
            -Verbosity Information
    }
    exec {
        Write-Host 'dotnet pack ExampleLibrary...'
        New-Item -ItemType Directory -Force ../packages | Out-Null
        dotnet pack -v n -c Release --no-build "-p:Version=$libVersion" --output ../packages
    }
    Pop-Location

    # set the application library dependency version.
    # NB in a real application this would not be needed, as you were going to
    #    have the library in a nother repository, and would manually update
    #    the application library dependency version, but here, as an
    #    example, we are doing it automatically.
    $project = Get-Content -Raw ExampleApplication\ExampleApplication.csproj
    $updatedProject = $project `
        -replace '(\<PackageReference Include="ExampleLibrary" Version=").+?(" /\>)',"`${1}$libVersion`${2}"
    if ($updatedProject -ne $project) {
        Write-Host "Setting the application library dependency version..."
        Set-Content `
            -NoNewline `
            -Path ExampleApplication\ExampleApplication.csproj `
            -Value $updatedProject
    }

    # build the application.
    Push-Location ExampleApplication
    exec {
        Write-Host 'dotnet build ExampleApplication...'
        dotnet build -v n -c Release "-p:Version=$appVersion"
    }
    exec {
        Write-Host 'sbom-tool generate ExampleApplication...'
        if (Test-Path bin/Release/net8.0/_manifest) {
            Remove-Item -Recurse -Force bin/Release/net8.0/_manifest
        }
        New-Item -ItemType Directory bin/Release/net8.0/_manifest | Out-Null
        dotnet tool run sbom-tool generate `
            -BuildDropPath bin/Release/net8.0 `
            -ManifestDirPath bin/Release/net8.0 `
            -BuildComponentPath . `
            -PackageSupplier ExampleCompany `
            -NamespaceUriBase https://sbom.example.com `
            -PackageName ExampleApplication `
            -PackageVersion $appVersion `
            -Verbosity Information
    }
    Pop-Location
}

function Invoke-StageTest {
    Push-Location ExampleApplication
    # validate the sbom.
    exec {
        Write-Host 'sbom-tool validate ExampleApplication...'
        dotnet tool run sbom-tool validate `
            -BuildDropPath bin/Release/net8.0 `
            -ManifestDirPath bin/Release/net8.0/_manifest `
            -ManifestInfo spdx:2.2 `
            -OutputPath bin/sbom-tool-validate-result.json `
            -Verbosity Information
    }
    # dump source link information.
    @('ExampleLibrary.dll', 'ExampleApplication.dll') | ForEach-Object {
        exec {
            Write-Host "sourcelink print-urls $_..."
            dotnet tool run sourcelink print-urls "bin/Release/net8.0/$_"
        }
        exec {
            Write-Host "sourcelink print-json $_..."
            dotnet tool run sourcelink print-json "bin/Release/net8.0/$_" | ConvertFrom-Json | ConvertTo-Json -Depth 100
        }
        exec {
            Write-Host "sourcelink print-documents $_..."
            dotnet tool run sourcelink print-documents "bin/Release/net8.0/$_"
        }
    }
    # dump the file version.
    @('ExampleLibrary.dll', 'ExampleApplication.dll') | ForEach-Object {
        Write-Host "Getting the $_ version..."
        Write-Host (Get-Item bin/Release/net8.0/$_).VersionInfo
    }
    # execute the application.
    # NB -532462766 (on Windows) or 134 (on Ubuntu) are the expected successful
    #    exit codes.
    exec -successExitCodes -532462766,134 {
        Write-Host 'executing ExampleApplication...'
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
            (Resolve-Path packages/*.nupkg) `
                --source gitlab
    }
}

Invoke-Expression "Invoke-Stage$([System.Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase(($stage -replace '-','')))"
