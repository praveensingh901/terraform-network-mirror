locals {
  aws_region       = "us-east-1"
  s3_bucket_name   = "adcb-network-terraform-provider-mirror"
  mirror_directory = "../mirror"

  tags = {
    owner = "adcb"
    acl   = "public-read"
  }
}

provider "aws" {
  region     = local.aws_region
  access_key = ""
  secret_key = ""

}

# Make sure all objects are public, Demo only - you can lock this down if you like
resource "aws_s3_bucket" "mirror" {
  bucket = local.s3_bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.mirror.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "good_example" {
  bucket                  = aws_s3_bucket.mirror.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "mirror" {
    depends_on = [
    aws_s3_bucket_public_access_block.good_example,
    aws_s3_bucket_ownership_controls.example,
  ]

  bucket = aws_s3_bucket.mirror.id
  acl    = "public-read"
}

# Loop through the mirror directory and upload it as-is to the bucket
resource "aws_s3_object" "mirror_objects" {
  for_each = fileset(local.mirror_directory, "**")

  bucket        = aws_s3_bucket.mirror.id
  key           = each.key
  source        = format("%s/%s", local.mirror_directory, each.value)
  force_destroy = false
  acl           = "public-read"

  # Hacky way to check for .json to set content type (JSON files MUST have this set)
  content_type = replace(each.value, ".json", "") != each.value ? "application/json" : ""

  # Set etag to pick up changes to files
  etag = filemd5(format("%s/%s", local.mirror_directory, each.value))
}

# Output the url needed in the Terraform CLI config
output "terraform-mirror-url" {
  value = format("https://%s/", aws_s3_bucket.mirror.bucket_domain_name)
}
