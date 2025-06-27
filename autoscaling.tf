resource "aws_autoscaling_group" "autosg" {
  launch_template {
    id      = aws_launch_template.ec2-template.id
    version = aws_launch_template.ec2-template.latest_version
  }

  min_size            = 2
  max_size            = 3
  desired_capacity    = 3
  vpc_zone_identifier = values(aws_subnet.private).*.id
  health_check_type   = "ELB"
  target_group_arns   = [aws_lb_target_group.app_target_group.arn]
  lifecycle {
    create_before_destroy = true
  }
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
  metrics_granularity = "1Minute"


  tag {
    key                 = "Name"
    value               = "${var.env}-autosg-instance"
    propagate_at_launch = true
  }
}
  
resource "aws_autoscaling_policy" "autosg-policy-up" {
    name = "autosg-policy-up"
    autoscaling_group_name = aws_autoscaling_group.autosg.name
    scaling_adjustment     = 1
    adjustment_type        = "ChangeInCapacity"
    cooldown               = 30
  
}
resource "aws_autoscaling_policy" "autosg-policy_down" {
  name                   = "utosg-policy_down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 30
  autoscaling_group_name = aws_autoscaling_group.autosg.name
}