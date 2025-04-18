# ------------------------------------------------------------------------------
# A Alias Record
# ------------------------------------------------------------------------------
resource "aws_route53_record" "alias" {
  count   = module.context.enabled ? 1 : 0
  zone_id = var.route53_zone_id
  name    = module.context.domain_name
  type    = "A"

  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = true
  }
}
