pipeline {
    agent any
    stages {
        stage('Test') { 
            steps {
                sh 'python /scripts/unit-tests/pac_test.py' 
            }
        }
    }
}
