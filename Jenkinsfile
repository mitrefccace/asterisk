pipeline {
	agent { 
	    dockerfile{
	        additionalBuildArgs  '--build-arg http_proxy=http://10.202.1.215:3128'
	        dir 'asterisk-codev'
	    }
	    
	}
    stages {
        stage('Test') { 
            steps {
                sh 'python /root/asterisk-codev/scripts/unit-tests/asterisk_jenkins_test.py' 
            }
        }
    }
}
