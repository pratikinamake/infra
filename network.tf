# network.tf

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "BU-PROD-VPC"
  }
}


resource "aws_subnet" "public" {
  count             = length(var.subnet_cidrs_public)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs_public[count.index]
  availability_zone = element(var.subnet_azs, count.index)
  tags = {
    Name = "BU-PROD-PUB-SUBNET ${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.subnet_cidrs_private)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs_private[count.index]
  availability_zone = element(var.subnet_azs, count.index)
  tags = {
    Name = "BU-PROD-PRI-SUBNET ${count.index + 1}"
  }

}


# Internet Gateway for the public subnet
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Route the public subnet traffic through the IGW
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.main.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

# Create a NAT gateway with an Elastic IP for each private subnet to get internet connectivity
resource "aws_eip" "gw" {
  vpc        = true
}

resource "aws_nat_gateway" "gw" {
  count         = 1
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  allocation_id = element(aws_eip.gw.*.id, count.index)
}

# Create a new route table for the private subnets, make it route non-local traffic through the NAT gateway to the internet
resource "aws_route_table" "private" {
  count = length(var.subnet_cidrs_private)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.gw.*.id, count.index)
  }
}

# Explicitly associate the newly created route tables to the private subnets (so they don't default to the main route table)
resource "aws_route_table_association" "private" {
  count = length(var.subnet_cidrs_private)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}
