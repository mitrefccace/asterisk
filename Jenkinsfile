pipeline {
    agent {
	docker {
	    image 'centos:7'
	    args '-v /home/centos/.ssl/star.pem:/etc/asterisk/keys/star.pem'
	    args '-v /home/centos/.ssl/key.pem:/etc/asterisk/keys/key.pem'
		}
	}
    stages {
    	stage('Build') { 
            steps {
                sh 'pwd && ls -lthr'
		sh 'cd asterisk-codev/scripts/ && ls -lthr'
		sh 'export IP_ADDR=$(hostname -I | awk "{print $1}")'
		sh 'sed -i -e "s/192.168.0.1/$IP_ADDR/g" .config.sample'
		sh 'sed -i -e "s/8.8.8.8/$IP_ADDR/g" .config.sample'
		sh 'sed -i -e "s/stun.example.com/stun.task3acrdemo.com/g" .config.sample'
		sh 'sed -i -e "s/hostname/ace-direct-mysql.ceq7afndeyku.us-east-1.rds.amazonaws.com/g" .config.sample'
		sh 'sed -i -e "s/database/asterisk/g/" .config.sample'
		sh 'sed -i -e "s/table/vasip/g" .config.sample'
		sh 'sed -i -e "s/somePass/2tZTp&b49#TSFYc2/g" .config.sample'
		sh 'mv .config.sample .config'
		sh 'echo "y n" | ./AD_asterisk_install'
            }
        }
        stage('Test') { 
            steps {
                sh 'python scripts/unit-tests/pac_test.py' 
            }
        }
    }
}
