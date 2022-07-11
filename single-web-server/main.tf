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

#the bash script referred on user_data will run a simple web server that always return the text "Hello, World"
/*
This is a bash script that writes the text “Hello, World” into index.html and runs a web server on port 8080 
using busybox (which is installed by default on Ubuntu) to serve that file at the URL “/”. We wrap the busybox 
command with nohup to ensure the web server keeps running even after this script exits and put an & at the end of the 
command so the web server runs in a background process and the script can exit rather than being blocked forever by the web server.

How do you get the EC2 Instance to run this script? Normally, instead of using an empty Ubuntu AMI, you would use a tool like 
Packer to create a custom AMI that has the web server installed on it. But again, in the interest of keeping this example simple, 
we’re going to run the script above as part of the EC2 Instance’s User Data, which AWS will execute when the instance is booting:
**/
resource "aws_instance" "example" {
    ami ="ami-0c55b159cbfafe1f0"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.sec-group-instance.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p 8080 &
                EOF

    tags = {
        Name = "terraform-example"
    }
}

# below we create a new aws_security_group because by default 
# AWS does not allow any incoming or outgoing traffic from an EC2 instance
# The CIDR block 0.0.0.0/0 is an IP address range that includes all possible IP addresses,
# so this security group allows incoming requests on port 8080 from any IP

resource "aws_security_group" "sec-group-instance" {
    name = "terraform-example-instance"

    ingress {
        from_port = 8080
        to_port   = 8080
        protocol  = "tcp"
        cidr_blocks = ["0.0.0.0/0"] 
    }
}