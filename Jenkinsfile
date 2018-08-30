pipeline {
    agent {
        label 'vs2017'
    }
    stages {
        stage('Build') {
            steps {
                powershell '''
                    # show all the environment variables.
                    Get-ChildItem env: `
                        | Format-Table -AutoSize `
                        | Out-String -Width 4096 -Stream `
                        | ForEach-Object {$_.Trim()}
                    '''
                powershell '''
                    Set-StrictMode -Version Latest
                    $FormatEnumerationLimit = -1
                    $ErrorActionPreference = 'Stop'
                    $ProgressPreference = 'SilentlyContinue'
                    trap {
                        Write-Output "ERROR: $_"
                        Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
                        Write-Output (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
                        Exit 1
                    }
                    function exec([ScriptBlock]$externalCommand) {
                        &$externalCommand
                        if ($LASTEXITCODE) {
                            throw "$externalCommand failed with exit code $LASTEXITCODE"
                        }
                    }

                    cd ExampleLibrary
                    exec {dotnet build -v n -c Release}
                    exec {dotnet pack -v n -c Release --no-build -p:PackageVersion=0.0.2 --output .}

                    cd ../ExampleApplication
                    exec {dotnet build -v n -c Release}
                    '''
            }
        }
        stage('Test') {
            steps {
                powershell '''
                    Set-StrictMode -Version Latest
                    $FormatEnumerationLimit = -1
                    $ErrorActionPreference = 'Stop'
                    $ProgressPreference = 'SilentlyContinue'
                    trap {
                        Write-Output "ERROR: $_"
                        Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
                        Write-Output (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
                        Exit 1
                    }
                    function exec([ScriptBlock]$externalCommand) {
                        &$externalCommand
                        if ($LASTEXITCODE) {
                            throw "$externalCommand failed with exit code $LASTEXITCODE"
                        }
                    }

                    cd ExampleApplication
                    exec {sourcelink print-urls bin/Release/netcoreapp2.1/ExampleApplication.dll}
                    exec {sourcelink print-json bin/Release/netcoreapp2.1/ExampleApplication.dll | ConvertFrom-Json | ConvertTo-Json -Depth 100}
                    exec {sourcelink print-documents bin/Release/netcoreapp2.1/ExampleApplication.dll}
                    dotnet run -v n -c Release --no-build
                    # force a success exit code because dotnet run is expected to fail due
                    # to an expected unhandled exception being raised by the application.
                    $LASTEXITCODE = 0
                    '''
            }
        }
    }
    post {
        success {
            archiveArtifacts '**/*.nupkg'
        }
        always {
            step $class: 'Mailer',
                recipients: 'jenkins@example.com',
                notifyEveryUnstableBuild: true,
                sendToIndividuals: false
        }
    }
}