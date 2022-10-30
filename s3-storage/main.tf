# below we configure Terraform to store the state in a s3 bucket (with encryption and locking)
terraform {
    backend "s3" {
        # The name of the S3 bucket to use
        bucket = "edgard-terraform-state"
        #The file path within the S3 bucket where the Terraform state file should be written
        key = "global/s3/terraform.tfstate"
        # The AWS region where the S3 bucket lives
        region = "us-east-2"

        # The DynamoDB table to use for locking
        # dynamodb_table = "terraform-up-and-running-locks"
        /*Setting this to true ensures your Terraform state will be encrypted on disk when stored in S3.
         We already enabled default encryption in the S3 bucket itself, so this is here as a second layer 
         to ensure that the data is always encrypted*/
        encrypt = true
    }
}

provider "aws" {
    region = "us-east-2"
}

# Below we will create a s3 resource that will be used to store our terraform state file
resource "aws_s3_bucket" "terraform_remote_state" {
    # This is the name of the S3 bucket
    bucket = "edgard-terraform-state" 

    # Enable versioning so we can see the full revison history of our state files.
    /*This block enables versioning on the S3 bucket, so that every update to a file in the bucket actually 
    creates a new version of that file. This allows you to see older versions of the file and revert to those
    older versions at any time*/
    versioning {
        enabled = true
    }

    # Enable server-side encryption by default
    /*This block turns server-side encryption on by default for all data written to this S3 bucket. 
    This ensures that your state files, and any secrets they may contain, are always encrypted on disk 
    when stored in S3*/
    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default {
                sse_algorithm = "AES256"
            }
        }
    }
}

# below we create a DynamoDb table to use for locking with Terraform
resource "aws_dynamodb_table" "terraform_locks" {
    name    = "terraform-up-and-running-locks"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "LockID"

    attribute {
        name = "LockID"
        type = "S"
    }
} 