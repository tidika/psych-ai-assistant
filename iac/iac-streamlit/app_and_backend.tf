############################ Cognito Integration #####################################

# User pool to manage user authentication
resource "aws_cognito_user_pool" "user_pool" {
  name = "${var.project_name}-user-pool"
  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "${var.project_name}-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  callback_urls = ["https://${var.domain_name}"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers         = ["COGNITO"]
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  explicit_auth_flows                  = ["ALLOW_ADMIN_USER_PASSWORD_AUTH", "ALLOW_CUSTOM_AUTH", "ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  generate_secret                      = true
}

resource "aws_cognito_user_pool_domain" "domain" {
  domain       = "${var.project_name}-auth"                                              
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

################################ EC2 Auto Scaling #######################################
#create ec2 template resource
resource "aws_launch_template" "streamlit_lt" {
  name = "${var.project_name}-streamlit-lt"
  image_id      = "ami-00ca32bbc84273381"
  instance_type = "t3.small"
  key_name      = "genAIapp"

  # Link the IAM role using its Instance Profile ARN
  iam_instance_profile {
    arn = "arn:aws:iam::930627915954:instance-profile/BedrockAccessRole"
  }

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "My-Streamlit-Instance"
    }
  }

  # User data to install Streamlit and start the app
  user_data = filebase64("${path.module}/user_data.sh")
}

##########################  Application Load Balancer (ALB) ##########################
#create autoscaling group resource
resource "aws_autoscaling_group" "streamlit_asg" {
  name                      = "${var.project_name}-streamlit-asg"
  vpc_zone_identifier       = [aws_subnet.private.id]
  desired_capacity          = 1
  max_size                  = 2
  min_size                  = 1
  target_group_arns         = [aws_lb_target_group.streamlit_tg.arn]

  launch_template {
    id      = aws_launch_template.streamlit_lt.id
    version = "$Latest"
  }

    # --- CRITICAL ADDITION FOR ASG ---
  depends_on = [
    aws_route53_record.app_record
  ]
}


# create loadbalancer resource
resource "aws_lb" "app_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
}

resource "aws_lb_listener" "http_8501" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "8501"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.streamlit_tg.arn
  }
}

resource "aws_lb_listener" "https_with_cognito" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn       = aws_cognito_user_pool.user_pool.arn
      user_pool_client_id = aws_cognito_user_pool_client.client.id
      user_pool_domain    = aws_cognito_user_pool_domain.domain.domain
      session_cookie_name = "AWSELBAuthSessionCookie"
      scope               = "openid"
      session_timeout     = 604800
      on_unauthenticated_request = "authenticate"
    }

    order = 1
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.streamlit_tg.arn
    order            = 2
  }

  depends_on = [
    aws_cognito_user_pool.user_pool,
    aws_cognito_user_pool_client.client,
    aws_cognito_user_pool_domain.domain
  ]
}

resource "aws_lb_target_group" "streamlit_tg" {
  name     = "${var.project_name}-streamlit-BB"
  port     = 8501 # Streamlit default port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path = "/"
    protocol = "HTTP"
  }
}

data "aws_route53_zone" "hosted_zone" {
  name = "mountpointe.com"
}

resource "aws_route53_record" "app_record" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = var.sub_domain
  type    = "A"

  alias {
    name                   = "dualstack.${aws_lb.app_alb.dns_name}"
    zone_id                = aws_lb.app_alb.zone_id
    evaluate_target_health = true
  }
}

############## deploy a seperate ec2 instance on public subnet #################
resource "aws_instance" "streamlit_instance" {
  # This should be a subnet in a private availability zone
  subnet_id = aws_subnet.public_az1.id

  launch_template {
    id      = aws_launch_template.streamlit_lt.id
    version = "$Latest"
  }

  tags = {
    Name = "My-Streamlit-Instance"
  }
  depends_on = [
    aws_route53_record.app_record
  ]
}