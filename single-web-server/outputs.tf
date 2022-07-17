# output "public_ip" {
#     value = aws_instance.example.public_ip
#     description = "the public ip of the web server"
# }
output "clb_dns_name" {
    value = aws_elb.classic_elb.dns_name
    description = "The domain name if the load balancer"
}