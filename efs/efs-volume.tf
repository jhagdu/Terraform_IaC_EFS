variable "vpc" {}
variable "efs_sg_id" {}
variable "private_key_pem" {}
variable "instance_public_ip" {}
variable "cf_domain_name" {}
variable "instance_az" {}


variable "dependencies" {
  type    = "list"
  default = []
}

resource "null_resource" "get_dependency" {
  provisioner "local-exec" {
    command = "echo ${length(var.dependencies)}"
  }
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

//Creating EFS Volume
resource "aws_efs_file_system" "file_system" {
  creation_token = "web-efs"

  depends_on = [
    data.aws_subnet.subnets,
    null_resource.get_dependency
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
  subnet_id       = [for s in data.aws_subnet.subnets : s.id if s.availability_zone == var.instance_az].0
  security_groups = ["${var.efs_sg_id}"]


  provisioner "remote-exec" {
    connection {
      agent       = "false"
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${var.private_key_pem}"
      host        = "${var.instance_public_ip}"
    }
    
    inline = [
      "sudo mount ${aws_efs_file_system.file_system.dns_name}:/ /var/www/html/",
      "sudo sed -i 's/CF_URL_Here/${var.cf_domain_name}/g' /home/ec2-user/webapp.html",
      "sudo cp /home/ec2-user/webapp.html /var/www/html/"
    ]
  }

  depends_on = [
    aws_efs_file_system.file_system
  ]
}

output "depended_on" {
  value = "${aws_efs_mount_target.mnt_trgt.id}"

  depends_on = [
    aws_efs_mount_target.mnt_trgt,
  ]
}