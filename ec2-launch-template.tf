# Create an IAM role for EC2 with SSM access

resource "aws_iam_role" "ssm-role" {
  name = "${var.env}-ec2-ssm-role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "${var.env}-ec2-Systems-Manager-service-role"
  }
}

# Create an IAM instance profile for the SSM role

resource "aws_iam_instance_profile" "ssm-profile" {
    name = "${var.env}-ssm-profile"
    role = aws_iam_role.ssm-role.name
  
}

# Attach policies to the SSM role

resource "aws_iam_policy_attachment" "ssm-policy" {
    for_each = local.ssm_policies
    name = "${var.env}-ssm-policy-attachment"
    policy_arn = each.value
}


# Create an EC2 launch template

resource "aws_launch_template" "ec2-template" {

    name_prefix = "${var.env}-launch-template"
    image_id = var.ami_id
    instance_type = var.instance_type
    iam_instance_profile {
      arn = aws_iam_instance_profile.ssm-profile.arn

    }
    monitoring {
      enabled = true
    }

    network_interfaces {
      associate_public_ip_address = false
      subnet_id                   = tolist(values(aws_subnet.private))[0].id
      security_groups = [aws_security_group.ec2-security_groups.id]
    }

      tag_specifications {
        resource_type = "instance"

      tags = {
        Name = "${var.env}-instance"
          }
  
      }
      lifecycle {
          create_before_destroy = true

        }
        update_default_version = true

      user_data = base64encode(data.template_file.user_data.rendered)

}

# User data template for EC2 instances

data "template_file" "user-data" {

  template = var.template
  vars = {
    efs_file_system_id = aws_efs_file_system.app_efs.id
  }
}

# Create a security group for EC2 instances

resource "aws_security_group" "ec2-security_groups" {
  name        = "${var.env}-ec2-sg"
  description = "Security group for the ec2"
  vpc_id      = aws_vpc.main.id


  dynamic "ingress" {
    for_each = var.ec2_sg_ingress_rules
    content {
      description     = format("Allow access for %s", ingress.key)
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = lookup(ingress.value, "protocol", "tcp")
      cidr_blocks     = lookup(ingress.value, "cidr_blocks", [])
      security_groups = lookup(ingress.value, "security_groups", [])
    }
  }
  dynamic "egress" {
    for_each = var.ec2_sg_egress_rules
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
    Name = "${var.env}-ec2SecurityGroup"
  }
}