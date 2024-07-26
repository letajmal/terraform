# instance
# ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
# ami lookup - ami ids are different from region to region - also its never a good idea to use ami names as it can become outdated
# ref: https://stackoverflow.com/questions/64053273/what-is-the-main-reason-amazon-machine-image-amis-i-e-ami-ids-in-aws-are-dif
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_name_pattern]
  }

  filter {
    name   = "virtualization-type"
    values = [var.virtualization_type]
  }

  owners = [var.ami_owners]
}

resource "aws_instance" "web" {
  ami = data.aws_ami.ubuntu.id
  # can i change instance type? Yes but it will incur downtime, aws will stop the instance and change the instance type before starting it again
  # check the instance compatibilty before doing this
  # ref: https://github.com/hashicorp/terraform-provider-aws/issues/4838
  instance_type = var.instance_type

  # EC2 stop protection
  disable_api_stop = var.disable_api_stop
  # EC2 termination protection
  disable_api_termination = var.disable_api_termination
  # for s3 access
  iam_instance_profile = aws_iam_instance_profile.web_iam.name
  # ssh key
  key_name   = aws_key_pair.web_deployer.key_name
  monitoring = var.monitoring
  root_block_device {
    delete_on_termination = var.root_block_device_delete_on_termination
    volume_size           = var.root_block_device_volume_size
    volume_type           = var.root_block_device_volume_type
  }
  security_groups = [aws_security_group.web_sg.name]
  user_data       = file("user_data.sh")
}

# eip
# ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip
resource "aws_eip" "web_lb" {
  instance = aws_instance.web.id
  domain   = "vpc"
}

# ssh key pair
# ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair
# use of tls provider is not recommended on production as terraform stores the keys in state file unencrypted
# ref: https://registry.terraform.io/providers/hashicorp/tls/latest/docs
# provider "tls" {}
# resource "tls_private_key" "example" {
#   algorithm = "RSA"
#   rsa_bits  = 2048
# }

resource "aws_key_pair" "web_deployer" {
  key_name   = "${var.resource_prefix}-key"
  public_key = var.public_key
}

# security groups
# ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "web_sg" {
  name        = "${var.resource_prefix}-sg"
  description = "Allow http, https, ssh"
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv4" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv6" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv6         = "::/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv6" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv6         = "::/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv6" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv6         = "::/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# iam for s3 access
resource "aws_iam_instance_profile" "web_iam" {
  name = "${var.resource_prefix}-iam"
  role = aws_iam_role.web_role.name
}

data "aws_iam_policy_document" "web_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "web_inline_policy" {
  statement {
    sid    = "1"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket_name}/${var.resource_prefix}/*",
    ]
  }

  statement {
    sid    = "2"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket_name}",
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"

      values = [
        "${var.resource_prefix}/*",
      ]
    }
  }
}

# An assume role policy allows specific entities (like users, services, or other accounts) to use a particular IAM role.
# It specifies who can assume the role and what actions they can perform.
# in data.aws_iam_policy_document.web_assume_role.json, we are assuming as an EC2 instance
resource "aws_iam_role" "web_role" {
  name               = "${var.resource_prefix}-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.web_assume_role.json
}

resource "aws_iam_role_policy" "web_policy" {
  name   = "${var.resource_prefix}-role-policy"
  role   = aws_iam_role.web_role.id
  policy = data.aws_iam_policy_document.web_inline_policy.json
}

