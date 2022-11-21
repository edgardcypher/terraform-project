# we declare where the state of this module should be saved
terraform {
    backend "s3" {
        # Replace this with your bucket name
        bucket          = "edgard-terraform-state"
        key             = "state/data-stores/mysql/terraform.tfstate"
        region          = "us-east-2"

        dynamodb_table  = "terraform-up-and-running-locks"
        encrypt         = true  
    }
}
# declare the cloud provider and the region in which the resource will be 
# deploy
provider "aws" {
    region = "us-east-2"
}

# define the rds resource we want to deploy
resource "aws_db_instance" "example" {
    identifier_prefix = "terraform-up-and-running"
    engine = "mysql"
    allocated_storage = 10
    instance_class = "db.t2.micro"
    skip_final_snapshot = true
    db_name             = "example_database"

    #how should we set the username and password?
    username = var.db_username
    password = var.db_password
}