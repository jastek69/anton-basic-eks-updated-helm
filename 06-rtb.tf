resource "aws_route_table" "eks_private_route_table" {
  vpc_id = aws_vpc.eks_host_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.eks_natgw.id
  }

  tags = {
    Name = "private"
  }
}

resource "aws_route_table" "eks_public_route_table" {
  vpc_id = aws_vpc.eks_host_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = {
    Name = "public"
  }
}

resource "aws_route_table_association" "eks_private_zone1" {
  subnet_id      = aws_subnet.eks_private_zone1.id
  route_table_id = aws_route_table.eks_private_route_table.id
}

resource "aws_route_table_association" "eks_private_zone2" {
  subnet_id      = aws_subnet.eks_private_zone2.id
  route_table_id = aws_route_table.eks_private_route_table.id
}

resource "aws_route_table_association" "eks_public_zone1" {
  subnet_id      = aws_subnet.eks_public_zone1.id
  route_table_id = aws_route_table.eks_public_route_table.id
}

resource "aws_route_table_association" "eks_public_zone2" {
  subnet_id      = aws_subnet.eks_public_zone2.id
  route_table_id = aws_route_table.eks_public_route_table.id
}
