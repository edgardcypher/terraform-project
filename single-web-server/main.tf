# this file is used to declare or configure a new provider
# here the provider is AWS but it could be AZURE or google cloud

provider "aws" {
    #infra will be deploy in the us-east-2 region
    region = "us-east-2"
}
# ---------------------------------------------------------------------------------------------------------------------
# GET THE LIST OF AVAILABILITY ZONES IN THE CURRENT REGION
# Every AWS accout has slightly different availability zones in each region. For example, one account might have
# us-east-1a, us-east-1b, and us-east-1c, while another will have us-east-1a, us-east-1b, and us-east-1d. This resource
# queries AWS to fetch the list for the current account and region.
# ---------------------------------------------------------------------------------------------------------------------
data "aws_availability_zones" "all_AZ" {}

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

# resource "aws_instance" "example" {
#     ami ="ami-0c6de836734de3280"
#     instance_type = "t2.micro"
#     vpc_security_group_ids = [aws_security_group.sec-group-instance.id]

#     user_data = <<-EOF
#                 #!/bin/bash
#                 echo "Hello, World" > index.html
#                 nohup busybox httpd -f -p "${var.server_port}" &
#                 EOF

#     tags = {
#         Name = "terraform-example"
#     }
# }

# below we create a new aws_security_group because by default 
# AWS does not allow any incoming or outgoing traffic from an EC2 instance
# The CIDR block 0.0.0.0/0 is an IP address range that includes all possible IP addresses,
# so this security group allows incoming requests on port 8080 from any IP

resource "aws_security_group" "sec-group-instance" {
    name = "terraform-example-instance"

    ingress {
        from_port = var.server_port
        to_port   = var.server_port
        protocol  = "tcp"
        cidr_blocks = ["0.0.0.0/0"] 
    }
}

# below we will be creating a launch configuration resource that will be
# used by a auto scaling group to scale cluster. The lauch configuration will configure
# EC2 that will be used by cluster. The lifecycle in the setting bellow tells us that 
# before adding a creating ec2 to cluster we need to delete the old one.

resource "aws_launch_configuration" "launch_conf_ec2" {
    image_id ="ami-0c6de836734de3280"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.sec-group-instance.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p "${var.server_port}" &
                EOF

    lifecycle {
    create_before_destroy = true
  }
}

# below we wil create an auto scaling group that will use the launch configuration
# above.This ASG will run between 2 and 10 EC2 instances but 2 will be default in the inital launch.
# ech instance will be tagged with the name "terraform-asg-example". we add availability_zones parameter to
#specifies into which AZ the EC2 instances should be deployed

resource "aws_autoscaling_group" "example_autoscaling" {
  launch_configuration = aws_launch_configuration.launch_conf_ec2.id
  availability_zones = data.aws_availability_zones.all_AZ.names

  min_size = 2
  max_size = 10

  # below we tell ASG to register each instance in the LB and also add health check type to ELB instead of EC2
  # and it will tell ASG to use the health check defined the LB to determine if an instance is healthy or not and auto replace
  # instances if the CLB reports them as unhealthy, so instances will be replaced not only if they are completely down but also for 
  # example if the stopped serving request because they ran out of memory or critical process crashed 
  load_balancers    = [aws_elb.classic_elb.name]
  health_check_type = "ELB"

  tag {
    key                 = "instance-name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

# below we will create a load balancer that will distribute traffic accross our ec2 server 
# and also give client users a single Ip address where the request will be sent. the IP address will
# the address of the load balancer server. AWS handles automatically the scalability and availability of ELB
# in different AZ based on the traffics and also failover.

resource "aws_elb" "classic_elb" {
    name = "classic-ELB"
    availability_zones      = data.aws_availability_zones.all_AZ.names
    security_groups         = [aws_security_group.sec_group_elb.id]
    
    # below we add a health check to periodically check the health of
    # the EC2, if an ec2 is unhealthy the lb balancer will periodically stop
    # routing the traffic to it. below we add a LB health check where LB will send an HTTP
    #request every 30s to "/" URL of each ec2. LB will mark the ec2 as healthy if it responds with 200 OK.
    health_check {
        target                  = "HTTP:${var.server_port}/"
        interval                = 30
        timeout                 = 3
        healthy_threshold       = 2
        unhealthy_threshold     = 2

    } 

    # this adds a listener for incoming HTTP requests.We are telling classic LB
    # to listen any HTTP requests on port 80 and then route them to the port used
    # by the instances in the ASG    
    listener {
        lb_port           = var.elb_port
        lb_protocol       = "http"
        instance_port     = var.server_port
        instance_protocol = "http"
    }
}

# below we create a new security group for the classic Lb since
# load balancer server as well as EC2 instances does not allow by default any inbound or outbound requests

resource "aws_security_group" "sec_group_elb" {
    # Allow all outbound request, this is needed for health checks of LB
    egress {
        from_port   = 0
        to_port     = 0
        protocol    ="-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Inbound HTTP from anywhere
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}