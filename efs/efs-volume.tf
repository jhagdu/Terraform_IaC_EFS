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
