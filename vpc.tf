#Vpc ressource

resource "aws_vpc" "main" {

  cidr_block= var.vpc_conf.cidr
  instance_tenancy = var.vpc_conf.instance_tenancy
  enable_dns_hostnames = var.vpc_conf.enable_dns_hostnames
  enable_dns_support = var.vpc_conf.enable_dns_support
  tags = {
    name= "${var.env}-vpc"
  }

}

#public subnets

resource "aws_subnet" "public_subnet" {
    
    for_each = var.public_subnets

    vpc_id = aws_vpc.main.id
    cidr_block = each.value
    map_public_ip_on_launch = true
    availability_zone = each.key
    tags = {
        Name = "${var.env}-public-${each.key}"
  }
  
}

#private subnets

resource "aws_subnet" "private_subnet" {
    
    for_each = var.private_subnets

    vpc_id = aws_vpc.main.id
    cidr_block = each.value
    map_public_ip_on_launch = false
    availability_zone = each.key
    tags = {
        Name = "${var.env}-private-${each.key}"
  }
  
}

#Elastic ip

resource "aws_eip" "nat_eip" {

    for_each = var.public_subnets
    domain = true
  
}

#Nat gateway

resource "aws_nat_gateway" "nat_gateway" {

    for_each = aws_eip.nat_eip
    allocation_id = each.value.id
    subnet_id     = values(local.target_subnet_id)[0]
    tags = {
        Name = "${var.env}-nat-gateway-${each.key}"
        }
  
}

#Create private routing tables 

resource "aws_route_table" "private" {
    for_each = var.private_subnets
    vpc_id = aws_vpc.main.id
    route = {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.nat_gateway[each.key].id
    }
    tags = {
         Name = "${var.env}-private-route-table-${each.key}"
    }

  
}

#Associate  private routing tables to subnets 

resource "aws_route_table_association" "private" {

         for_each = aws_subnet.private
         subnet_id = each.value.id
         route_table_id = aws_route_table.private[each.key].id 
}

#Create internet gateway

resource "aws_internet_gateway" "internet-gateway" {

    vpc_id = aws_vpc.main.id
    tags = {
       Name = "${var.env}-internet-gateway"
    }
  
}

#Create public routing table

resource "aws_route_table" "public" {
    for_each = var.public_subnets
    vpc_id = aws_vpc.main.id
    route = {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.internet-gateway.id
    }
    tags = {
         Name = "${var.env}-public-route-table"
    }

  
}

#Associate  public route table to public subnets 

resource "aws_route_table_association" "public" {

         for_each = aws_subnet.public_subnet
         subnet_id = each.value.id
         route_table_id = aws_route_table.public.id 
}
