pipeline {
	agent { 
	    dockerfile{
	        additionalBuildArgs  '--build-arg http_proxy=http://10.202.1.215:3128 --build-arg CI_MODE=true'
		args '-e CI_MODE=true -e HOSTNAME=jenkins.task3acrdemo.com -e PUBLIC_IP=8.8.8.8'
	    }
	    
	}
    stages {
        stage('Test') { 
            steps {
                sh 'python /root/asterisk-ad/scripts/unit-tests/asterisk_jenkins_test.py' 
            }
        }
    }
}
