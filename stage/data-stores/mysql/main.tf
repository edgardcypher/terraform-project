provider "aws" {
    region = "us-east-2"
}

# we declare where the state of this module should be saved
terraform {
    backend "s3" {
        # Replace this with your bucket name
        bucket          = "edgard-terraform-state"
        #The file path within the S3 bucket where the Terraform state file of mysql db should be written
        key             = "state/data-stores/mysql/terraform.tfstate"
        region          = "us-east-2"

        dynamodb_table  = "terraform-up-and-running-locks"
        encrypt         = true  
    }
}
# the reusable module is called.
module "staging_mysql_db_cluster" {
    source = "../../../modules/data-stores/mysql"

    db_username = "user_mysql"
    db_password = "randomChar80"
    engine_type = "mysql"
    storage_size = 10
    instance_type = "db.t2.micro"
    name_rds      = "stagingRds"
    skip_final_snapshot = true
    identifier   = "stage-msql"
}