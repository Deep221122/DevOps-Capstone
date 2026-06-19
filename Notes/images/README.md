# Project Implementation

- clone my Repository: [Repository Link](https://github.com/Deep221122/DevOps-Capstone.git)
- or elese you can manually create folder named frontend
    under that create index.html
    - copy code shown here
- create folder for infra
    - create terraform
        - main.tf
        - variables.tf
        - outputs.tf
        - terraform.tfvars
- create folder for CICD
    - .github
        - workflows
            - terraform.yml
            - frontend.yml
            - backend-deploy.yml
- create folder for Backend
    - create folder generate-presigned-url
        - main.py (add code)
    - create folder process-uploaded-file
        - main.py (add code)


## Make sure AWS is configured in your system

- verify

```bash
aws configure list
aws sts get-caller-identity
```
- if you don't have any of this
- download aws CLI in your system
- install verify using: aws --version

- next step is to go to AWS Console Create IAM user with Administrator access policy
- Click on create Access Key
- you can see Access Key and Secret Key
- Go to your system and run aws configure
- enter access key then secret key and then origin: us-east-1, format: json
- after this it will be configured

## For Project we need 3 Buckets

1. S3 Remote Backend (create manually)
2. Frontend Hosting (create using terraform)
3. Backend uploading files (create using terraform)

# Let's create bucket for Remote Backend and DynamoDb for locking table

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket devops-accelerator-platform-tf-state-1906 \
  --region us-east-1

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name devops-accelerator-tf-locker \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Create zip for Lambda

```bash
cd backend/process-uploaded-file
zip -r lambda.zip .

cd ../generate-presigned-url
zip -r lambda.zip .
```