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

//Creating Variable for AMI_Type
variable "ami_type" {
  type    = string
  default = "t2.micro"
}
