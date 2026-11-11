# Public hosted zone for the web domain. donan.site stays at its registrar; the registrar delegates the
# subdomain here with four NS records (see output web_zone_name_servers).
resource "aws_route53_zone" "web" {
  name    = var.web_domain
  comment = "FCourt web (delegated from the parent domain registrar)"
}
