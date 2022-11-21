# below we configure Terraform to store the state in a s3 bucket (with encryption and locking)
terraform {
    backend "s3" {
        # The name of the S3 bucket to use
        bucket = "edgard-terraform-state"
        #The file path within the S3 bucket where the Terraform state file should be written
        key = "workspaces-cluster-webservers/terraform.tfstate"
        # The AWS region where the S3 bucket lives
        region = "us-east-2"

        # The DynamoDB table to use for locking
        dynamodb_table = "terraform-up-and-running-locks"
        /*Setting this to true ensures your Terraform state will be encrypted on disk when stored in S3.
         We already enabled default encryption in the S3 bucket itself, so this is here as a second layer 
         to ensure that the data is always encrypted*/
        encrypt = true
    }
}

# this file is used to declare or configure a new provider
# here the provider is AWS but it could be AZURE or google cloud
# we comment the provider because it needs to be declared at the root module
# provider "aws" {
#     #infra will be deploy in the us-east-2 region
#     region = "us-east-2"
# }
# ---------------------------------------------------------------------------------------------------------------------
# GET THE LIST OF AVAILABILITY ZONES IN THE CURRENT REGION
# Every AWS account has slightly different availability zones in each region. For example, one account might have
# us-east-1a, us-east-1b, and us-east-1c, while another will have us-east-1a, us-east-1b, and us-east-1d. This resource
# queries AWS to fetch the list for the current account and region.
# ---------------------------------------------------------------------------------------------------------------------
data "aws_availability_zones" "all_AZ" {}

# below we declare terraform data source to read the state file of mysql rds from the s3 bucket. doing this 
# we can pull in all mysql database's state data to be used anywhere in the config file  
data "terraform_remote_state" "db" {
    backend = "s3"
    config = {
        bucket  = "edgard-terraform-state"
        key     = "state/data-stores/mysql/terraform.tfstate"
        region  = "us-east-2"
    }
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
# used by a auto scaling group to scale cluster. The launch configuration will configure
# EC2 that will be used by cluster. The lifecycle in the setting below tells us that 
# we need to create a new ec2 instance before delete old one.

resource "aws_launch_configuration" "launch_conf_ec2" {
    image_id ="ami-0c6de836734de3280"
    instance_type = "t2.small"
    security_groups = [aws_security_group.sec-group-instance.id]

    user_data = templatefile("user-data.sh",{
        server_port = var.server_port
        db_address  = data.terraform_remote_state.db.outputs.address
        db_port     = data.terraform_remote_state.db.outputs.port
    })

    # Required when using a launch configuration with an ASG.
    lifecycle {
    create_before_destroy = true
  }
}

# below we wil create an auto scaling group that will use the launch configuration
# above.This ASG will run between 2 and 10 EC2 instances but 2 will be default in the inital launch.
# each instance will be tagged with the name "terraform-asg-example". we add availability_zones parameter to
#specifies into which AZ the EC2 instances should be deployed

resource "aws_autoscaling_group" "example_autoscaling" {
  launch_configuration = aws_launch_configuration.launch_conf_ec2.id
  availability_zones = data.aws_availability_zones.all_AZ.names

  min_size = 2
  max_size = 10

  # below we tell ASG to register each instance in the LB and also add health check type to be ELB instead of EC2
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
# and also give client users a single Ip address where the request will be sent. the IP address will be
# the address of the load balancer server. AWS handles automatically the scalability and availability of ELB
# in different AZ based on the traffics and also failover.

resource "aws_elb" "classic_elb" {
    name = "${var.cluster_name}-ELB"
    availability_zones      = data.aws_availability_zones.all_AZ.names
    security_groups         = [aws_security_group.sec_group_elb.id]
    
    # below we add a health check to periodically check the health of
    # the EC2, if an ec2 is unhealthy the lb balancer will periodically stop
    # routing the traffic to it. below we add a LB health check where LB will send an HTTP
    #request every 30s to "/" URL of each ec2. LB will mark the ec2 as healthy if it responds with 200 OK twice and unhealthy otherwise.
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