resource "aws_iam_role" "ec2_role" {
  name               = var.role_name
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags = {
    tag-key = "tag-value"
  }
}
resource "aws_iam_role_policy" "ec2" {
  name   = "${var.role_name}-ec2_policy"
  role   = aws_iam_role.ec2_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Action": ["ec2:*"],
          "Effect": "Allow",
          "Resource": "*"
      }
  ]
}
EOF
}

resource "aws_iam_role_policy" "s3" {
  name   = "${var.role_name}-s3_policy"
  role   = aws_iam_role.ec2_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
      {
        "Effect" : "Allow",
        "Action" : ["s3:ListBucket"],
        "Resource" : ["*"]
      },
      {
        "Effect" : "Allow",
        "Action" : ["s3:GetObject",s3:AbortMultipartUpload","s3:PutObject","s3:ListBucket","s3:GetObjectVersion","s3:PutObjectAcl","s3:ListMultipartUploadParts","s3:DeleteObject"],
        "Resource" : ["*"]
      }
    ]
}
EOF
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.role_name}-profile"
  role = aws_iam_role.ec2_role.name
}