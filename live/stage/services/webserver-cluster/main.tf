provider "aws" {
    region = "us-east-2"
}

# below we configure Terraform to store the state in a s3 bucket (with encryption and locking)
terraform {
    backend "s3" {
        # The name of the S3 bucket to use
        bucket = "edgard-terraform-state"
        #The file path within the S3 bucket where the Terraform state file of webservers should be written
        key = "workspaces-cluster-webservers/terraform.tfstate"
        # The AWS region where the S3 bucket lives
        region = "us-east-2"

        # The DynamoDB table to use for locking
        dynamodb_table = "terraform-up-and-running-locks"
        /*Setting this to true ensures your Terraform state will be encrypted on disk when stored in S3.
         We already enabled default encryption in the S3 bucket itself, so this is here as a second layer 
         to ensure that the data is always encrypted*/
        encrypt = true
    }
}

# the reusable module is called.
module "webserver_cluster" {
    source = "https://github.com/edgardcypher/terraform_modules//services/webserver-cluster?ref=v0.0.1"

    # below we set value of variables that are used in the module
    cluster_name = "webservers-stage"
    # db_remote_state_bucket = "edgard-terraform-state"
    # db_remote_state_key = "state/data-stores/mysql/terraform.tfstate"

    instance_type = "t2.micro"
    min_size      = 2
    max_size      = 2
}