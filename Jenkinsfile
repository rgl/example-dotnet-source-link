pipeline {
    agent {
        label 'vs2022'
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
                powershell './build.ps1 build'
            }
        }
        stage('Test') {
            steps {
                powershell './build.ps1 test'
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