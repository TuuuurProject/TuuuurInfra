output "site_url" {
  value = "http://${module.lb.ip}"
}
