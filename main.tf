//Describing Provider
provider "aws" {
  region  = "us-east-1"
  profile = "default"
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
