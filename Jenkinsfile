pipeline {
    agent any
    parameters {
        string(name: 'Environment', defaultValue: 'prod', description: 'Environemnt')
    }
    stages {
        stage('Init') {
            steps {
                sh "terraform init"
            }
        }
        stage('Validate') {
            steps {
                sh "terraform validate"
            }
        }
        stage('Plan') {
            steps {
                sh """ terraform plan --var-file ${params.Environment}.tfvars """
            }
        }
    }
}