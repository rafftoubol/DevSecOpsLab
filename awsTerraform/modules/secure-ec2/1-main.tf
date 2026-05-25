# Fetch latest hardened Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Security group - deny all by default
resource "aws_security_group" "this" {
  name        = "${var.name}-${var.env}-sg"
  description = "Security group for ${var.name}"
  vpc_id      = var.vpc_id

  # No inbound rules - deny all inbound by default

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-${var.env}-sg"
    Env  = var.env
  }
}

# IAM role for SSM access - no SSH keys needed
resource "aws_iam_role" "this" {
  name = "${var.name}-${var.env}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.name}-${var.env}-role"
    Env  = var.env
  }
}

# Attach SSM policy so you can access instance without SSH
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-${var.env}-profile"
  role = aws_iam_role.this.name
}

resource "aws_instance" "this" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  # No SSH key - use SSM Session Manager instead
  key_name = null

  # Block public IP
  associate_public_ip_address = false

  # Enforce IMDSv2 - prevents SSRF attacks against metadata service
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Encrypted root volume
  root_block_device {
    encrypted   = true
    kms_key_id  = var.kms_key_arn
    volume_type = "gp3"
    volume_size = 20
  }

  # Disable termination protection accidental deletes
  disable_api_termination = false

  monitoring = true

  tags = {
    Name = "${var.name}-${var.env}"
    Env  = var.env
  }
}
