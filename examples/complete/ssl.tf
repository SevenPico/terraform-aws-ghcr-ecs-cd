#------------------------------------------------------------------------------
# SSL Updater Labels
#------------------------------------------------------------------------------
module "ssl_updater_context" {
  source  = "registry.terraform.io/SevenPico/context/null"
  version = "2.0.0"
  context = module.context.self
  name    = "ssl-updater"
}


# ------------------------------------------------------------------------------
# SSL Certificate
# ------------------------------------------------------------------------------
module "ssl_certificate" {
  source     = "registry.terraform.io/SevenPico/ssl-certificate/aws"
  version    = "8.0.10"
  context    = module.context.self
  enabled    = module.context.enabled
  attributes = ["ssl", "certificate"]

  additional_dns_names              = []
  additional_secrets                = {}
  create_mode                       = "ACM_Only"
  create_secret_update_sns          = true
  import_filepath_certificate       = null
  import_filepath_certificate_chain = null
  import_filepath_private_key       = null
  import_secret_arn                 = null
  keyname_certificate               = "CERTIFICATE"
  keyname_certificate_chain         = "CERTIFICATE_CHAIN"
  keyname_private_key               = "CERTIFICATE_PRIVATE_KEY"
  kms_key_deletion_window_in_days   = var.kms_key_deletion_window_in_days
  kms_key_enable_key_rotation       = var.kms_key_enable_key_rotation
  secret_read_principals = {
    AllowRootRead = {
      type = "Service"
      identifiers = [
        "events.amazonaws.com"
      ]
      condition = {
        test = null
        values = [
        ]
        variable = null
      }
    }
  }
  secret_update_sns_pub_principals = {}
  secret_update_sns_sub_principals = {}
  zone_id                          = var.route53_zone_id
}
