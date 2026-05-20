resource "aws_subnet" "private_zone1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.64.0/19"
  availability_zone = "eu-north-1a"

  tags = {
    Name                                 = "private-subnet-1"
    "kubernetes.io/cluster/internal-elb" = "1"
    "kubernetes.io/cluster/dev-demo"     = "owned"
  }
}


resource "aws_subnet" "private_zone2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.96.0/19"
  availability_zone = "eu-north-1b"

  tags = {
    Name                                 = "private-subnet-2"
    "kubernetes.io/cluster/internal-elb" = "1"
    "kubernetes.io/cluster/dev-demo"     = "owned"
  }
}
