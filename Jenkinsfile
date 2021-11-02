pipeline {
    agent any
    parameters {
        string(name: 'Environment', defaultValue: 'prod', description: 'Environemnt')
    }

    environment {
        ARM_USE_MSI = 'true'
        ARM_SUBSCRIPTION_ID = '0df0b217-e303-4931-bcbf-af4fe070d1ac'
        ARM_TENANT_ID = '812aea3a-56f9-4dcb-81f3-83e61357076e'
        GOOGLE_CHAT_URL = 'https://chat.googleapis.com/v1/spaces/AAAA2NbUb4k/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=yb6Kh6ho0fFNVClLvcf2k7I3fIUqVQUxND52Bvzt6Ag%3D'
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
                sh """ terraform plan --var-file ${params.Environment}.tfvars -out tf.plan """
            }
        }
        stage('Deploy approval') {
            steps {
                script {
                    if (params.Environment == "prod") {
                       input "Deploy to prod?"
                    } else {
                        echo 'Deploying to staging'
                    }
               }
           }
        }
        stage('Apply') {
            steps {
                 script {
                    if (params.Environment == "prod") {
                        echo 'I only execute on the master branch'
                        //sh """ terraform apply --var-file ${params.Environment}.tfvars --auto-aprove """
                    } else {
                        //sh """ terraform apply --var-file ${params.Environment}.tfvars --auto-aprove """
                        echo 'I apply in somewhere else'

                    }
                }
            }
        }
        stage('Notification') {
            steps {
               googlechatnotification (
                   url: "https://chat.googleapis.com/v1/spaces/AAAALrF97Rs/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=JjxLuuMHJBwdIeAYRD2z6G0xwXF5AuMyCqESoNhBEAg%3D",
                   message: 'Shoshana',
                   sameThreadNotification: true,
                   suppressInfoLoggers: true
               )
            }
        }
    }
}