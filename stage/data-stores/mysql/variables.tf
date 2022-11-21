variable "db_username" {
    description = "The username for the database"
    type        = string
    sensitive   = true # to indicate that the varable value is a secret so terraform won't log the value when running "plan or apply"
}

variable "db_password" {
    description = "The password for the database"
    type        = string
    sensitive   = true
}