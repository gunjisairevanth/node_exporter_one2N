############## ACM Certificate #############

resource "aws_acm_certificate" "cert" {
  domain_name       = var.metrics_domain_name
  validation_method = "DNS"
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "nginx-cert" {
  domain_name       = var.files_domain_name
  validation_method = "DNS"
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_acm_certificate_validation" "nginx-cert" {
  certificate_arn         = aws_acm_certificate.nginx-cert.arn
  validation_record_fqdns = [for record in aws_route53_record.nginx_cert_validation : record.fqdn]
}


resource "aws_route53_record" "nginx_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.nginx-cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}


###################### AWS EKS Deployment ##############################
resource "kubernetes_manifest" "node_exporter_deployment" {
  manifest = yamldecode(file("../kubernetes/deployment/node_exporter-cronjob.yaml"))
  depends_on = [aws_eks_node_group.my_node_group]
}
resource "kubernetes_manifest" "node_exporter_nginx_deployment" {
  manifest = yamldecode(file("../kubernetes/deployment/nginx.yaml"))
  depends_on = [aws_eks_node_group.my_node_group]
}


resource "kubernetes_manifest" "node_exporter_nginx_configmap" {
  manifest = yamldecode(file("../kubernetes/deployment/nginx-conf.yaml"))
  depends_on = [aws_eks_node_group.my_node_group]
}

resource "kubernetes_manifest" "sync_metrics_configmap" {
  manifest = yamldecode(file("../kubernetes/deployment/sync-metrics-conf.yaml"))
  depends_on = [aws_eks_node_group.my_node_group]
}


resource "kubernetes_manifest" "cron_job" {
  manifest = yamldecode(file("../kubernetes/cronjob/job.yaml"))
  depends_on = [aws_eks_node_group.my_node_group]
}


############## Kubernetes Service with LoadBalancer #############

resource "kubernetes_service" "node-exporter-service" {
  metadata {
    name = "node-exporter"
    annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
        "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"         = aws_acm_certificate.cert.arn
    }
  }

  spec {
    selector = {
      app = "node-exporter"
    }

    port {
      protocol = "TCP"
      port     = 443
      target_port = 9100
    }

    type = "LoadBalancer"
  }

  depends_on = [aws_route53_record.cert_validation,aws_eks_node_group.my_node_group]  # Ensure Route 53 record is created before the service

}


resource "kubernetes_service" "nginx-service" {
  metadata {
    name = "nginx"
    annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
        "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"         = aws_acm_certificate.nginx-cert.arn
    }
  }

  spec {
    selector = {
      app = "nginx"
    }

    port {
      protocol = "TCP"
      port     = 443
      target_port = 80
    }

    type = "LoadBalancer"
  }

}


# Create a Route 53 record for the load balancer URL
data "aws_elb" "node_exporter_lb" {
    name = split("-", kubernetes_service.node-exporter-service.status.0.load_balancer.0.ingress.0.hostname)[0]
}


data "aws_elb" "nginx_exporter_lb" {
    name = split("-", kubernetes_service.nginx-service.status.0.load_balancer.0.ingress.0.hostname)[0]
}


resource "aws_route53_record" "node_exporter_lb" {
  zone_id         = var.zone_id
  name            = var.metrics_domain_name  # Replace with your domain name
  type            = "A"
 alias {
    name                   = data.aws_elb.node_exporter_lb.dns_name
    zone_id                = data.aws_elb.node_exporter_lb.zone_id
    evaluate_target_health = false
  }
}



resource "aws_route53_record" "nginx_lb" {
  zone_id         = var.zone_id
  name            = var.files_domain_name  # Replace with your domain name
  type            = "A"
 alias {
    name                   = data.aws_elb.nginx_exporter_lb.dns_name
    zone_id                = data.aws_elb.nginx_exporter_lb.zone_id
    evaluate_target_health = false
  }
}
