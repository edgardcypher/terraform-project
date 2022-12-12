output "prod_alb_dns_name" {
  value       = module.prod_webserver_cluster.alb_dns_name
  description = "The domain name of the load balancer"
}