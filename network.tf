# network.tf

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "UAT-VPC"
  }
}


resource "aws_subnet" "public" {
  count             = length(var.subnet_cidrs_public)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs_public[count.index]
  availability_zone = element(var.subnet_azs, count.index)
  tags = {
    Name = "UAT-PUB-SUBNET ${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.subnet_cidrs_private)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs_private[count.index]
  availability_zone = element(var.subnet_azs, count.index)
  tags = {
    Name = "UAT-PRI-SUBNET ${count.index + 1}"
  }

}


resource "aws_internet_gateway" "internet-gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "uat-internet-gw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet-gw.id}"
  }
  tags = {
    Name = "uat-public"
  }
}

resource "aws_route_table_association" "public" {
  count = "${length(var.subnet_cidrs_public)}"

  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}


# Create a NAT gateway with an Elastic IP for each private subnet to get internet connectivity
resource "aws_eip" "gw" {
  vpc        = true
}

resource "aws_nat_gateway" "gw" {
  count         = 1
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  allocation_id = element(aws_eip.gw.*.id, count.index)
  tags = {
    Name = "Nat-IG"
   }
}



resource "aws_route_table" "private" {
  count = 1
  vpc_id = aws_vpc.main.id
  route {
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = element(aws_nat_gateway.gw.*.id, count.index)
  
  }
  tags = {
   Name = "uat-private"
 }
}

resource "aws_route_table_association" "private" {
  count = length(var.subnet_cidrs_private)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}



