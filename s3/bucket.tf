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
