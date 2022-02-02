pipeline {
  agent any
  stages {
    stage('Build') {
      steps {
        git(url: 'https://github.com/amulsharma/Devops.git', branch: 'main')
        sh 'myscrpt.sh'
      }
    }

  }
}