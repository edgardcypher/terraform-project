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