provider "aws" {
    region = "us-east-2"
}

# the reusable module is called.
module "prod_mysql_db_cluster" {
    source = "../../../modules/data-stores/mysql"
}