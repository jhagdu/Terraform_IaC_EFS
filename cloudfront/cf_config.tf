variable "origin_id" {}
variable "domain_name" {}

variable "dependencies" {
  type    = "list"
  default = []
}

resource "null_resource" "get_dependency" {
  provisioner "local-exec" {
    command = "echo ${length(var.dependencies)}"
  }
}

//Creating CloutFront with S3 Bucket Origin
resource "aws_cloudfront_distribution" "s3-web-distribution" {
  origin {
    domain_name = "${var.domain_name}"
    origin_id   = "${var.origin_id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "S3 Web Distribution"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }

  tags = {
    Name        = "Web-CF-Distribution"
    Environment = "Production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  depends_on = [
    null_resource.get_dependency,
  ]
}

output "cf_domain_name" {
  value = "${aws_cloudfront_distribution.s3-web-distribution.domain_name}"

  depends_on = [
    aws_cloudfront_distribution.s3-web-distribution,
  ]
}
