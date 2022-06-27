# this file is used to declare or configure a new provider
# here the provider is AWS but it could be AZURE or google cloud

provider "aws" {
    #infra will be deploy in the us-east-2 region
    region = "us-east-2"
}

# To create a create the declaration is
// resource "<PROVIDER>_<TYPE>" "<NAME>" {
//  [CONFIG …]
// }
# Where PROVIDER is the name of a provider (e.g., aws), TYPE is the type of resources to create 
# in that provider (e.g., instance), NAME is an identifier you can use throughout the Terraform 
# code to refer to this resource (e.g., example), and CONFIG consists of one or more arguments 
# that are specific to that resource (e.g., ami = "ami-0c55b159cbfafe1f0"). For the aws_instance resource.

# for this provider we create a server resource EC2 with the name example
# the type of instance is t2.micro and it will run an AMI .
resource "aws_instance" "example" {
    ami ="ami-0c55b159cbfafe1f0"
    instance_type = "t2.micro"

    tags = {
        Name = "terraform-example"
    }
}