# Create a VPC with public and private subnets
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.project_name}-igw" }
}

# NAT Gateway requires an Elastic IP address
resource "aws_eip" "nat_gateway_eip" {
  tags = {
    Name = "${var.project_name}-nat-gateway-eip"
  }
}

# NAT Gateway deployed in the public subnet
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_az1.id
  tags = {
    Name = "${var.project_name}-nat-gateway"
  }
}

resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-subnet-az1" }
}

resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-subnet-az2" }
}


resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "${var.project_name}-private-subnet" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}

resource "aws_route_table_association" "public_az1" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}


# --------------------------------------------------------------------------
# -- Additions for Private Connectivity to S3 and Bedrock --
# --------------------------------------------------------------------------

## S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3_gateway_endpoint" {
  vpc_id      = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  tags = { Name = "${var.project_name}-s3-gateway-endpoint" }
}

## S3 Route Table Association
resource "aws_vpc_endpoint_route_table_association" "s3_endpoint_rt_association" {
  vpc_endpoint_id = aws_vpc_endpoint.s3_gateway_endpoint.id
  route_table_id  = aws_route_table.private.id
}

## Bedrock Interface Endpoint Security Group
resource "aws_security_group" "bedrock_endpoint_sg" {
  vpc_id = aws_vpc.main.id
  description = "Security group for Bedrock VPC interface endpoint"
  name = "${var.project_name}-bedrock-endpoint-sg"
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # Allow traffic from the private subnet (where your EC2 instance will be)
    cidr_blocks = [aws_subnet.private.cidr_block]
  }
  tags = { Name = "${var.project_name}-bedrock-endpoint-sg" }
}


## Bedrock Runtime VPC Interface Endpoint (for invoking models)
resource "aws_vpc_endpoint" "bedrock_interface_endpoint" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.bedrock"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true # This allows you to use the default Bedrock DNS name
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.bedrock_endpoint_sg.id]
  tags = { Name = "${var.project_name}-bedrock-interface-endpoint" }
}

## Bedrock Agent Runtime VPC Interface Endpoint (for knowledge bases)
resource "aws_vpc_endpoint" "bedrock_agent_runtime_interface_endpoint" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.bedrock-agent-runtime"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true # Recommended to enable private DNS
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.bedrock_endpoint_sg.id]
  tags                = { Name = "${var.project_name}-bedrock-agent-runtime-endpoint" }
}