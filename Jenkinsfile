pipeline {
    agent {
	Docker {
		image 'centos:7'
		}
	}
    stages {
        stage('Test') { 
            steps {
                sh 'python scripts/unit-tests/pac_test.py' 
            }
        }
    }
}
