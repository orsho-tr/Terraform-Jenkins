pipeline {
    agent any
    parameters {
        string(name: 'Environment', defaultValue: 'prod', description: 'Environemnt')
    }

    environment {
        ARM_USE_MSI = 'true'
        ARM_SUBSCRIPTION_ID = '0df0b217-e303-4931-bcbf-af4fe070d1ac'
        ARM_TENANT_ID = '812aea3a-56f9-4dcb-81f3-83e61357076e'
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