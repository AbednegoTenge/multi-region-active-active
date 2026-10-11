

resource "aws_lb" "this" {
  name               = "${local.region}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = aws_subnet.subnet[*].id
}

resource "aws_lb_target_group" "this" {
  name     = "${local.region}-tg"
  target_type = "lambda"

  health_check {
    enabled = true
    path                = "/health/deep"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}


resource "aws_lb_target_group_attachment" "this" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = aws_lambda_function.this.arn
  depends_on       = [aws_lambda_permission.allow_lb]
}


