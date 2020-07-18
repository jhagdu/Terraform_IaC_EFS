//Describing Provider
provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

//Creating Variable for AMI_ID
variable "ami_id" {
  type    = string
  default = "ami-08f3d892de259504d"
}

//Creating Variable for VPC
variable "vpc" {
  type    = string
  default = "vpc-e96e8d94"
}

//Getting all Subnet IDs of a VPC
data "aws_subnet_ids" "subnet" {
  vpc_id = var.vpc
}

data "aws_subnet" "subnets" {
  for_each = data.aws_subnet_ids.subnet.ids
  id       = each.value

  depends_on = [
    data.aws_subnet_ids.subnet
  ]
}

//Creating Variable for AMI_Type
variable "ami_type" {
  type    = string
  default = "t2.micro"
}

//Creating Key
resource "tls_private_key" "tls_key" {
  algorithm = "RSA"
}

//Generating Key-Value Pair
resource "aws_key_pair" "generated_key" {
  key_name   = "web-env-key"
  public_key = "${tls_private_key.tls_key.public_key_openssh}"

  depends_on = [
    tls_private_key.tls_key
  ]
}

//Saving Private Key PEM File
resource "local_file" "key-file" {
  content  = "${tls_private_key.tls_key.private_key_pem}"
  filename = "web-env-key.pem"

  depends_on = [
    tls_private_key.tls_key
  ]
}

//Creating Security Group
resource "aws_security_group" "web-SG" {
  name        = "web-env-SG"
  description = "Web Environment Security Group"
  vpc_id      = var.vpc

  //Adding Rules to Security Group 
  ingress {
    description = "SSH Rule"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NFS Rule"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP Rule"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

//Creating Security Group For EFS
resource "aws_security_group" "efs-sg" {
  name        = "efs-sg"
  description = "EFS SG"
  vpc_id      = var.vpc

  //Adding Rules to Security Group 
  ingress {
    description = "NFS Rule"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    security_groups = [aws_security_group.web-SG.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

//Creating a S3 Bucket
resource "aws_s3_bucket" "web-bucket" {
  bucket = "web-static-data-bket"
  acl    = "public-read"
}

//Putting Objects in S3 Bucket
resource "aws_s3_bucket_object" "web-object1" {
  bucket = "${aws_s3_bucket.web-bucket.bucket}"
  key    = "iac1.png"
  source = "iac1.png"
  acl    = "public-read"
}

//Putting Objects in S3 Bucket
resource "aws_s3_bucket_object" "web-object2" {
  bucket = "${aws_s3_bucket.web-bucket.bucket}"
  key    = "iac2.png"
  source = "iac2.png"
  acl    = "public-read"
}

//Putting Objects in S3 Bucket
resource "aws_s3_bucket_object" "web-object3" {
  bucket = "${aws_s3_bucket.web-bucket.bucket}"
  key    = "iac3.png"
  source = "iac3.png"
  acl    = "public-read"
}

//Creating CloutFront with S3 Bucket Origin
resource "aws_cloudfront_distribution" "s3-web-distribution" {
  origin {
    domain_name = "${aws_s3_bucket.web-bucket.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.web-bucket.id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "S3 Web Distribution"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.web-bucket.id}"

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
    aws_s3_bucket.web-bucket
  ]
}

//Launching EC2 Instance
resource "aws_instance" "web" {
  ami             = "${var.ami_id}"
  instance_type   = "${var.ami_type}"
  key_name        = "${aws_key_pair.generated_key.key_name}"
  security_groups = ["${aws_security_group.web-SG.name}","default"]

  //Labelling the Instance
  tags = {
    Name = "Web-Env"
    env  = "Production"
  }
/*
  //Put CloudFront URLs in our Website Code
  provisioner "local-exec" {
    command = "sed -i 's/CF_URL_Here/${aws_cloudfront_distribution.s3-web-distribution.domain_name}/g' webapp.html"
  }
*/  
  //Copy our Wesite Code i.e. HTML File in Instance Webserver Document Rule
  provisioner "file" {
    connection {
      agent       = false
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${tls_private_key.tls_key.private_key_pem}"
      host        = "${aws_instance.web.public_ip}"
    }

    source      = "webapp.html"
    destination = "/home/ec2-user/webapp.html" 
  }


  //Executing Commands to initiate WebServer in Instance Over SSH 
  provisioner "remote-exec" {
    connection {
      agent       = "false"
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${tls_private_key.tls_key.private_key_pem}"
      host        = "${aws_instance.web.public_ip}"
    }
    
    inline = [
      "sudo yum install httpd -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
    ]

  }

  //Storing Key and IP in Local Files
  provisioner "local-exec" {
    command = "echo ${aws_instance.web.public_ip} > public-ip.txt"
  }

  depends_on = [
    aws_security_group.web-SG,
    aws_key_pair.generated_key
  ]
}

//Creating EFS Volume
resource "aws_efs_file_system" "file_system" {
  creation_token = "web-efs"

  depends_on = [
    aws_instance.web
  ]
}

//Creating Policy for EFS
resource "aws_efs_file_system_policy" "efs-policy" {
  file_system_id = "${aws_efs_file_system.file_system.id}"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Id": "efs-policy-wizard-eda0b278-4348-4642-b4c9-490bbf334873",
    "Statement": [
        {
            "Sid": "efs-statement-c7a84ce0-72a9-420a-bea0-84194267aeff",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": [
                "elasticfilesystem:ClientMount",
                "elasticfilesystem:ClientWrite",
                "elasticfilesystem:ClientRootAccess"
            ]
        }
    ]
}
POLICY
}

//Mount Targets of EFS Volume
resource "aws_efs_mount_target" "mnt_trgt" {
  file_system_id  = "${aws_efs_file_system.file_system.id}"
  subnet_id       = [for s in data.aws_subnet.subnets : s.id if s.availability_zone == aws_instance.web.availability_zone].0
  security_groups = [aws_security_group.efs-sg.id]


  provisioner "remote-exec" {
    connection {
      agent       = "false"
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${tls_private_key.tls_key.private_key_pem}"
      host        = "${aws_instance.web.public_ip}"
    }
    
    inline = [
      "sudo mount aws_efs_file_system.file_system.dns_name:/ /var/www/html/",
      "sudo sed -i 's/CF_URL_Here/${aws_cloudfront_distribution.s3-web-distribution.domain_name}/g' /home/ec2-user/webapp.html",
      "sudo cp /home/ec2-user/webapp.html /var/www/html/"
    ]
  }

  depends_on = [
    aws_instance.web,
    aws_efs_file_system.file_system
  ]
}


//Open Web Site
resource "null_resource" "open_site" {
  provisioner "local-exec" {
    command = "start chrome ${aws_instance.web.public_dns}/webapp.html"
  }

  depends_on = [
    aws_efs_mount_target.mnt_trgt
  ]
}
