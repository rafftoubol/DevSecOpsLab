resource "aws_subnet" "private" {
  count = length(local.private_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name                                 = "private-subnet-${count.index}"
    "kubernetes.io/cluster/internal-elb" = "1"
    "kubernetes.io/cluster/dev-demo"     = "owned"
  }
}
