resource "aws_eip" "eks_nat_eip" {
  #vpc = true

  tags = {
    Name = "nat"
  }
}

resource "aws_nat_gateway" "eks_natgw" {
  allocation_id = aws_eip.eks_nat_eip.id
  subnet_id     = aws_subnet.eks_public_zone1.id

  tags = {
    Name = "nat"
  }

  depends_on = [aws_internet_gateway.eks_igw]
}
