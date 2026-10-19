data "aws_cloudfront_origin_request_policy" "Managed-AllViewerExceptHostHeader" {
  name = "Managed-AllViewerExceptHostHeader"
}
data "aws_cloudfront_cache_policy" "Managed-CachingDisabled" {
  name = "Managed-CachingDisabled"
}
data "aws_cloudfront_cache_policy" "Managed-CachingOptimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "main" {
  provider = aws.us-east-1

  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2and3"
  aliases         = [var.app_domain]

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  origin {
    origin_id   = "functionurl"
    domain_name = replace(replace(aws_lambda_function_url.app.function_url, "https://", ""), "/", "")

    # Host must stay the function URL's, so Rails learns its public host from this.
    custom_header {
      name  = "x-forwarded-host"
      value = var.app_domain
    }
    custom_header {
      name  = "x-origin-verify"
      value = random_bytes.cloudfront_verify.base64
    }
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = 60
    }
  }

  ordered_cache_behavior {
    target_origin_id       = "functionurl"
    path_pattern           = "/vite/*"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.Managed-CachingOptimized.id
    viewer_protocol_policy = "redirect-to-https"
  }

  default_cache_behavior {
    target_origin_id         = "functionurl"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = data.aws_cloudfront_cache_policy.Managed-CachingDisabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.Managed-AllViewerExceptHostHeader.id
    viewer_protocol_policy   = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "random_bytes" "cloudfront_verify" {
  length = 32
}
resource "aws_ssm_parameter" "cloudfront_verify" {
  name  = "/myapp/${var.name}/CLOUDFRONT_VERIFY"
  type  = "SecureString"
  value = random_bytes.cloudfront_verify.base64
}
