pipeline {
    agent {
	docker {
		image 'centos7' 
	}
    }
    stages {
        stage('Test') { 
            steps {
                sh 'python /scripts/unit-tests/pac_test.py' 
            }
        }
    }
}
