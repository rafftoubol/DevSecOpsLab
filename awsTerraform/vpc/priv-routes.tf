resource "aws_route_table" "private_zone1" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Private Route Table Zone 1"
  }
}

resource "aws_route_table" "private_zone2" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Private Route Table Zone 2"
  }
}

resource "aws_route_table_association" "private_zone1" {
  subnet_id      = aws_subnet.private_zone1.id
  route_table_id = aws_route_table.private_zone1.id
}

resource "aws_route_table_association" "private_zone2" {
  subnet_id      = aws_subnet.private_zone2.id
  route_table_id = aws_route_table.private_zone2.id
}
