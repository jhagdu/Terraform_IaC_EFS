//Describing Provider
provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

module "ec2_module" {
  source = "./ec2"

  vpc = var.vpc
  ami_id = var.ami_id
  ami_type = var.ami_type
}

module "s3_module" {
  source = "./s3"
}

module "cf_module" {
  source = "./cloudfront"

  origin_id = module.s3_module.bucket_id
  domain_name = module.s3_module.bucket_domain_name

  dependencies = [
    module.s3_module.bucket_domain_name,
  ]
}

module "efs_module" {
  source = "./efs"

  vpc = var.vpc
  instance_az = module.ec2_module.instance_az
  efs_sg_id = module.ec2_module.efs_sg_id
  private_key_pem = module.ec2_module.private_key_pem
  instance_public_ip = module.ec2_module.instance_public_ip
  cf_domain_name = module.cf_module.cf_domain_name

  dependencies = [
    module.cf_module.cf_domain_name,
  ]
}

//Open Web Site
resource "null_resource" "open_site" {
  provisioner "local-exec" {
    command = "start chrome ${module.ec2_module.instance_public_dns}/webapp.html"
  }

  depends_on = [
    module.efs_module.depended_on
  ]
}
