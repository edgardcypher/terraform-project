variable "server_port" {
    description = "the port that will be used by the web server for http requests"
    type = number
    default = 8080
}

variable "elb_port" {
    description = "the port that will be used by the elb server to listen http requests"
    type = number
    default = 80
}

variable "cluster_name" {
    description = "The name use for all the cluster resources"
    type        = string 
}

variable "db_remote_state_bucket" {
    description = "The name of the s3 bucket for the DB remote state"
    type        = string
}

variable "db_remote_state_key" {
    description = "The path for the DB remote state in S3 "
    type        = string
}