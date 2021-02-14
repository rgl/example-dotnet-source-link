pipeline {
    agent {
        label 'vs2019'
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
                    function exec([ScriptBlock]$externalCommand, [string]$stderrPrefix='', [int[]]$successExitCodes=@(0)) {
                        $eap = $ErrorActionPreference
                        $ErrorActionPreference = 'Continue'
                        try {
                            &$externalCommand 2>&1 | ForEach-Object {
                                if ($_ -is [System.Management.Automation.ErrorRecord]) {
                                    "$stderrPrefix$_"
                                } else {
                                    "$_"
                                }
                            }
                            if ($LASTEXITCODE -notin $successExitCodes) {
                                throw "$externalCommand failed with exit code $LASTEXITCODE"
                            }
                        } finally {
                            $ErrorActionPreference = $eap
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
                    function exec([ScriptBlock]$externalCommand, [string]$stderrPrefix='', [int[]]$successExitCodes=@(0)) {
                        $eap = $ErrorActionPreference
                        $ErrorActionPreference = 'Continue'
                        try {
                            &$externalCommand 2>&1 | ForEach-Object {
                                if ($_ -is [System.Management.Automation.ErrorRecord]) {
                                    "$stderrPrefix$_"
                                } else {
                                    "$_"
                                }
                            }
                            if ($LASTEXITCODE -notin $successExitCodes) {
                                throw "$externalCommand failed with exit code $LASTEXITCODE"
                            }
                        } finally {
                            $ErrorActionPreference = $eap
                        }
                    }

                    cd ExampleApplication
                    # NB sourcelink print-urls is expected to return 4; it means there's at least one
                    #    document without a URL (the automatically generated
                    #    %AppData%/Local/Temp/.NETCoreApp,Version=v3.1.AssemblyAttributes.cs file).
                    exec {sourcelink print-urls bin/Release/netcoreapp3.1/ExampleApplication.dll}
                    exec {sourcelink print-json bin/Release/netcoreapp3.1/ExampleApplication.dll | ConvertFrom-Json | ConvertTo-Json -Depth 100}
                    exec {sourcelink print-documents bin/Release/netcoreapp3.1/ExampleApplication.dll}
                    exec {dotnet run -v n -c Release --no-build} -successExitCodes -532462766
                    # force a success exit code because dotnet run is expected to fail due
                    # to an expected unhandled exception being raised by the application.
                    Exit 0
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
                recipients: emailextrecipients([
                    culprits(),
                    requestor()
                ]),
                notifyEveryUnstableBuild: true,
                sendToIndividuals: false
        }
    }
}