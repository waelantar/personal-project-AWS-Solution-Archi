# Create a Route 53 hosted zone for the domain

resource "aws_route53_zone" "main" {
    name = "waelterraform.devops"
  
}
# Data source to reference the Route 53 hosted zone created above

data "aws_route53_zone" "main" {
  name = "waelterraform.devops." # Ensure the domain name ends with a dot
  depends_on = [ aws_route53_zone.main ]
}

# Create a Route 53 record to point to the application load balancer

resource "aws_route53_record" "record" {
    zone_id = aws_route53_zone.main.id
    name = "www.waelterraform.devops"
    type = "A"
    alias {
      name = aws_lb.app_alb.dns_name
      zone_id = aws_lb.app_alb.zone_id
      evaluate_target_health = "true"
    }
  
}


# Request an ACM certificate for the domain

resource "aws_acm_certificate" "certificate" {

    domain_name       = "www.waelterraform.devops"
    validation_method = "DNS"
    subject_alternative_names = ["*.waelterraform.devops"]

    tags = {
        Environment = "development"
    }

    lifecycle {
        create_before_destroy = true
    }
}

# Create Route 53 records for certificate validation

resource "aws_route53_record" "certificate-validation" {
  for_each = {
    for dvo in aws_acm_certificate.certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.id
}

# Validate the ACM certificate using the DNS validation records
  

resource "aws_acm_certificate_validation" "example_cert" {
  certificate_arn         = aws_acm_certificate.certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate-validation : record.fqdn]
  depends_on              = [aws_route53_record.certificate-validation]

}