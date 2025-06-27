# Create an AWS Application Load Balancer (ALB)

resource "aws_lb" "alb" {
    name = "${var.env}-alb"
    internal = false
    load_balancer_type = "application"
    subnets            = values(aws_subnet.public).*.id
    security_groups = [aws_security_group.alb-sg]
    tags = {
      Name = "${var.env}-ApplicationLB" 
    }

}

# Create a security group for the ALB

resource "aws_security_group" "alb_sg" {
  name        = "${var.env}-alb-sg"
  description = "Security group for the application load balancer"
  vpc_id      = aws_vpc.main.id

# Ingress rules for the ALB security group

  dynamic "ingress" {
    for_each = var.alb_sg_ingress_rules
    content {
      description     = format("Allow access for %s", ingress.key)
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = lookup(ingress.value, "protocol", "tcp")
      cidr_blocks     = lookup(ingress.value, "cidr_blocks", [])
      security_groups = lookup(ingress.value, "security_groups", [])
    }
  }

  # Egress rules for the ALB security group

  dynamic "egress" {
    for_each = var.alb_sg_egress_rules
    content {
      description     = format("Allow access for %s", egress.key)
      from_port       = egress.value.from_port
      to_port         = egress.value.to_port
      protocol        = lookup(egress.value, "protocol", "tcp")
      cidr_blocks     = lookup(egress.value, "cidr_blocks", [])
      security_groups = lookup(egress.value, "security_groups", [])
    }
  }
  tags = {
    Name = "${var.env}-ALBSecurityGroup"
  }
}

# Create an HTTPS listener for the ALB

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.certificate.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Create an HTTP listener for the ALB

resource "aws_lb_target_group" "app_target_group" {
  name     = "${var.env}-targetgroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }
}

