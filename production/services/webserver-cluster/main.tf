provider "aws" {
    region = "us-east-2"
}

# the reusable module is called.
module "prod_webserver_cluster" {
    source = "../../../modules/services/webserver-cluster"

    # below we set value of variables that are used in the module
    cluster_name = "webservers-prod"
    db_remote_state_bucket = "edgard-terraform-state"
    db_remote_state_key = "terraform-prod"
 
    instance_type = "t2.micro" # i could use m4.large but it is not part of aws tier free
    min_size      = 2
    max_size      = 10
}

#below we will define an ASG scheduling in production which will 
# allow us to increate instances during bussiness hours to respond to load and decrease at the end of the day.
/*This code uses one aws_autoscaling_schedule resource to increase the number of servers to 
10 during the morning hours (the recurrence parameter uses cron syntax, so “0 9 * * *” means “9 a.m. every day”) 
and a second aws_autoscaling_schedule resource to decrease the number of servers at night (“0 17 * * *” means “5 p.m. every day”)*/

resource "aws_autoscaling_schedule" "scale_up_in_morning" {
    scheduled_action_name   = "scale-out-during-business-hours"
    min_size                = 2
    max_size                = 10
    desired_capacity        = 10
    recurrence              = "0 9 * * *"

    autoscaling_group_name  = module.prod_webserver_cluster.asg_name # name of ASG where the scheduling should be used
}

resource "aws_autoscaling_schedule" "scale_down_at_night" {
    scheduled_action_name = "scale-in-at-night"
    min_size              = 2
    max_size              = 10
    desired_capacity      = 2
    recurrence            = "0 17 * * *"

    autoscaling_group_name  = module.prod_webserver_cluster.asg_name # name of ASG where the scheduling should be used

}