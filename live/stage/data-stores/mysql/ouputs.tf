output "address" {
  value       = module.staging_mysql_db_cluster.address
  description = "The domain name of the load balancer"
}

output "port" {
    value = module.staging_mysql_db_cluster.port
    description = "The port the database is listening on"
}