# mainConnection.tf

# Standard AWS Provider Block
terraform {
  required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = ">= 1.0"
        }
    }
}

data "aws_caller_identity" "current" {}

resource "aws_ec2_transit_gateway_vpc_attachment" "TGW_CON_VPC" {
    count = (length(var.TGW_CON_VPC) > 0 ? length(var.TGW_CON_VPC) : 0)

    transit_gateway_id = var.TGW_CON_VPC[count.index].TGW_ID
    vpc_id             = var.TGW_CON_VPC[count.index].VPC_ID
    subnet_ids         = var.TGW_CON_VPC[count.index].SN_IDS
    tags = {
        Name = "${var.TGW_CON_VPC[count.index].NAME}"
    }
}

resource "aws_ec2_transit_gateway_route_table_association" "TGW_RTB_ASS_VPC" {
    count = (length(var.TGW_CON_VPC) > 0 ? length(var.TGW_CON_VPC) : 0)
    depends_on = [ aws_ec2_transit_gateway_vpc_attachment.TGW_CON_VPC ]

    transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.TGW_CON_VPC[count.index].id
    transit_gateway_route_table_id = var.TGW_CON_VPC[count.index].TGW_RTB_ID
}

resource "aws_ec2_transit_gateway_route_table_propagation" "TGW_RTB_PROP_VPC" {
    count = (length(var.TGW_CON_VPC) > 0 ? length(var.TGW_CON_VPC) : 0)
depends_on = [ aws_ec2_transit_gateway_vpc_attachment.TGW_CON_VPC ]

    transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.TGW_CON_VPC[count.index].id
    transit_gateway_route_table_id = var.TGW_CON_VPC[count.index].TGW_RTB_ID
}

resource "aws_vpn_connection" "TGW_CON_CGW" {
    count = (length(var.TGW_CON_CGW) > 0 ? length(var.TGW_CON_CGW) : 0)

    transit_gateway_id  = var.TGW_CON_CGW[count.index].TGW_ID
    customer_gateway_id = var.TGW_CON_CGW[count.index].CGW_ID
    type                = try(var.TGW_CON_CGW[count.index].TYPE, null)
    static_routes_only  = try(var.TGW_CON_CGW[count.index].STATIC_ROUTE, null)
    tunnel1_preshared_key = try(var.TGW_CON_CGW[count.index].TUNNEL1_PSK, null)
    tunnel2_preshared_key = try(var.TGW_CON_CGW[count.index].TUNNEL2_PSK, null)

    tags = {
        Name = "${var.TGW_CON_CGW[count.index].NAME}"
    }
}

resource "aws_ec2_tag" "TGW_CON_CGW_TAG" {
    count = (length(var.TGW_CON_CGW) > 0 ? length(var.TGW_CON_CGW) : 0)    
    
    resource_id = aws_vpn_connection.TGW_CON_CGW[count.index].transit_gateway_attachment_id
    key         = "Name"
    value       = "${var.TGW_CON_CGW[count.index].NAME}"
}

resource "aws_ec2_transit_gateway_route_table_association" "TGW_RTB_ASS_CGW" {
    count = (length(var.TGW_CON_CGW) > 0 ? length(var.TGW_CON_CGW) : 0)

    transit_gateway_attachment_id  = aws_vpn_connection.TGW_CON_CGW[count.index].transit_gateway_attachment_id
    transit_gateway_route_table_id = var.TGW_CON_CGW[count.index].TGW_RTB_ID
}

resource "aws_ec2_transit_gateway_route_table_propagation" "TGW_RTB_PROP_CGW" {
    count = (length(var.TGW_CON_CGW) > 0 ? length(var.TGW_CON_CGW) : 0)

    transit_gateway_attachment_id  = aws_vpn_connection.TGW_CON_CGW[count.index].transit_gateway_attachment_id
    transit_gateway_route_table_id = var.TGW_CON_CGW[count.index].TGW_RTB_ID
}

resource "aws_ec2_transit_gateway_route" "TGW_CON_CGW_ROUTE" {
    count = (length(var.TGW_CON_CGW) > 0 ? length(var.TGW_CON_CGW) : 0)

    destination_cidr_block         = var.TGW_CON_CGW[count.index].DESTINATION_CIDR
    transit_gateway_attachment_id  = aws_vpn_connection.TGW_CON_CGW[count.index].transit_gateway_attachment_id
    transit_gateway_route_table_id = var.TGW_CON_CGW[count.index].TGW_RTB_ID
    blackhole                      = false
}

resource "aws_ec2_transit_gateway_peering_attachment" "TGW_PEER_REQUEST" {
    count = (length(var.TGW_PEER_REQUEST) > 0 ? length(var.TGW_PEER_REQUEST) : 0)  

    transit_gateway_id      = var.TGW_PEER_REQUEST[count.index].TGW_ID
    peer_account_id         = var.TGW_PEER_REQUEST[count.index].PEER_OWNER_ID
    peer_region             = var.TGW_PEER_REQUEST[count.index].PEER_REG_NAME
    peer_transit_gateway_id = var.TGW_PEER_REQUEST[count.index].PEER_TGW_ID
    tags = {
      Name = "${var.TGW_PEER_REQUEST[count.index].NAME}"
    }
}

resource "null_resource" "WAIT_FOR_TGW_PEER_REQUEST" {
    count = (length(aws_ec2_transit_gateway_peering_attachment.TGW_PEER_REQUEST) > 0 ? length(aws_ec2_transit_gateway_peering_attachment.TGW_PEER_REQUEST) : 0)
    
    depends_on = [aws_ec2_transit_gateway_peering_attachment.TGW_PEER_REQUEST]
    
    triggers = {
        attachment_id = aws_ec2_transit_gateway_peering_attachment.TGW_PEER_REQUEST[count.index].id
    }

    provisioner "local-exec" {
        command = <<-EOT
        TGW_PEER_REQUEST_STATE=$(aws ec2 describe-transit-gateway-peering-attachments --filters Name=transit-gateway-attachment-id,Values=${self.triggers.attachment_id} --query 'TransitGatewayPeeringAttachments[0].State' --output text --profile=thkim-Seoul) 
        while [[ $TGW_PEER_REQUEST_STATE != "available" ]]; do
            sleep 10
            TGW_PEER_REQUEST_STATE=$(aws ec2 describe-transit-gateway-peering-attachments --filters Name=transit-gateway-attachment-id,Values=${self.triggers.attachment_id} --query 'TransitGatewayPeeringAttachments[0].State' --output text --profile=thkim-Seoul)
        done    
        EOT
        interpreter = ["bash", "-c"]   
        on_failure = continue
    }
}

resource "aws_ec2_transit_gateway_route" "TGW_RTB_PEER_REQUEST_ROUTE" {
    count = (length(null_resource.WAIT_FOR_TGW_PEER_REQUEST) > 0 ? length(null_resource.WAIT_FOR_TGW_PEER_REQUEST) : 0)
    depends_on = [ null_resource.WAIT_FOR_TGW_PEER_REQUEST ]

    transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.TGW_PEER_REQUEST[count.index].id
    transit_gateway_route_table_id = var.TGW_PEER_REQUEST[count.index].TGW_RTB_ID
    destination_cidr_block         = var.TGW_PEER_REQUEST[count.index].DESTINATION_CIDR
    blackhole                      = false
}

resource "aws_ec2_transit_gateway_route_table_association" "TGW_RTB_PEER_REQUEST_ASS" {
    count = (length(null_resource.WAIT_FOR_TGW_PEER_REQUEST) > 0 ? length(null_resource.WAIT_FOR_TGW_PEER_REQUEST) : 0)
    depends_on = [ null_resource.WAIT_FOR_TGW_PEER_REQUEST ]

    transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.TGW_PEER_REQUEST[count.index].id
    transit_gateway_route_table_id = var.TGW_PEER_REQUEST[count.index].TGW_RTB_ID
}

resource "aws_ec2_transit_gateway_route" "TGW_PEER_REQUEST_ADD_ROUTE" {
    count = (length(null_resource.WAIT_FOR_TGW_PEER_REQUEST) > 0 ? length(null_resource.WAIT_FOR_TGW_PEER_REQUEST) : 0)
    depends_on = [ null_resource.WAIT_FOR_TGW_PEER_REQUEST ]

    destination_cidr_block         = var.TGW_PEER_REQUEST_ADD_ROUTE[count.index].DESTINATION_CIDR
    transit_gateway_attachment_id  = var.TGW_PEER_REQUEST_ADD_ROUTE[count.index].TGW_ATT_ID
    transit_gateway_route_table_id = var.TGW_PEER_REQUEST_ADD_ROUTE[count.index].TGW_RTB_ID
    blackhole                      = var.TGW_PEER_REQUEST_ADD_ROUTE[count.index].BLACKHOLE
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "TGW_PEER_ACCEPT" {
    count = (length(var.TGW_PEER_ACCEPT) > 0 ? length(var.TGW_PEER_ACCEPT) : 0)

    transit_gateway_attachment_id = var.TGW_PEER_ACCEPT[count.index].TGW_ATT_ID
    tags = {
        Name = "${var.TGW_PEER_ACCEPT[count.index].NAME}"
    }
}

resource "null_resource" "WAIT_FOR_TGW_PEER_ACCEPT" {
    count = (length(aws_ec2_transit_gateway_peering_attachment_accepter.TGW_PEER_ACCEPT) > 0 ? length(aws_ec2_transit_gateway_peering_attachment_accepter.TGW_PEER_ACCEPT) : 0)
    depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.TGW_PEER_ACCEPT]
    
    triggers = {
        attachment_id = aws_ec2_transit_gateway_peering_attachment_accepter.TGW_PEER_ACCEPT[count.index].id
    }

    provisioner "local-exec" {
        command = <<-EOT
        TGW_PEER_ACCEPT_STATE=$(aws ec2 describe-transit-gateway-peering-attachments --filters Name=transit-gateway-attachment-id,Values=${self.triggers.attachment_id} --query 'TransitGatewayPeeringAttachments[0].State' --output text --profile=thkim-Singapore) 
        while [[ $TGW_PEER_ACCEPT_STATE != "available" ]]; do
            sleep 10
            TGW_PEER_ACCEPT_STATE=$(aws ec2 describe-transit-gateway-peering-attachments --filters Name=transit-gateway-attachment-id,Values=${self.triggers.attachment_id} --query 'TransitGatewayPeeringAttachments[0].State' --output text --profile=thkim-Singapore)
        done    
        EOT
        interpreter = ["bash", "-c"]   
        on_failure = continue
    }
}

resource "aws_ec2_transit_gateway_route" "TGW_PEER_ACCEPT_ROUTE" {
    count = (length(null_resource.WAIT_FOR_TGW_PEER_ACCEPT) > 0 ? length(null_resource.WAIT_FOR_TGW_PEER_ACCEPT) : 0)
    depends_on = [ null_resource.WAIT_FOR_TGW_PEER_ACCEPT ]

    transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.TGW_PEER_ACCEPT[count.index].id
    transit_gateway_route_table_id = var.TGW_PEER_ACCEPT[count.index].TGW_RTB_ID
    destination_cidr_block         = var.TGW_PEER_ACCEPT[count.index].DESTINATION_CIDR
    blackhole                      = false
}

resource "aws_ec2_transit_gateway_route_table_association" "TGW_PEER_ACCEPT_ASS" {
    count = (length(null_resource.WAIT_FOR_TGW_PEER_ACCEPT) > 0 ? length(null_resource.WAIT_FOR_TGW_PEER_ACCEPT) : 0)
    depends_on = [ null_resource.WAIT_FOR_TGW_PEER_ACCEPT ]

    transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.TGW_PEER_ACCEPT[count.index].id
    transit_gateway_route_table_id = var.TGW_PEER_ACCEPT[count.index].TGW_RTB_ID
}

resource "aws_ec2_transit_gateway_route" "TGW_PEER_ACCEPT_ADD_ROUTE" {
    count = (length(null_resource.WAIT_FOR_TGW_PEER_ACCEPT) > 0 ? length(null_resource.WAIT_FOR_TGW_PEER_ACCEPT) : 0)
    depends_on = [ null_resource.WAIT_FOR_TGW_PEER_ACCEPT ]

    destination_cidr_block         = var.TGW_PEER_ACCEPT_ADD_ROUTE[count.index].DESTINATION_CIDR
    transit_gateway_attachment_id  = var.TGW_PEER_ACCEPT_ADD_ROUTE[count.index].TGW_ATT_ID
    transit_gateway_route_table_id = var.TGW_PEER_ACCEPT_ADD_ROUTE[count.index].TGW_RTB_ID
    blackhole                      = var.TGW_PEER_ACCEPT_ADD_ROUTE[count.index].BLACKHOLE
}

# resource "aws_ec2_transit_gateway_connect" "TGW_CON_DX" {
#     count = (length(var.TGW_CON_DX) > 0 ? length(var.TGW_CON_DX) : 0)

#     transport_attachment_id = var.TGW_CON_DX[count.index].TGW_ATT_ID
#     transit_gateway_id      = var.TGW_CON_DX[count.index].TGW_ID
#     tags = {
#         Name = "${var.TGW_CON_DX[count.index].NAME}"
#     }
# }

# resource "aws_vpn_connection" "VPN_CON_CGW" {
#     count = (length(var.VPN_CON_CGW) > 0 ? length(var.VPN_CON_CGW) : 0)

#     vpn_gateway_id      = var.VPN_CON_CGW[count.index].VGW_ID
#     customer_gateway_id = var.VPN_CON_CGW[count.index].CGW_ID
#     type                = try(var.VPN_CON_CGW[count.index].TYPE, null)
#     static_routes_only  = try(var.VPN_CON_CGW[count.index].STATIC_ROUTE, null)
#     tunnel1_preshared_key = try(var.VPN_CON_CGW[count.index].TUNNEL1_PSK, null)
#     tunnel2_preshared_key = try(var.VPN_CON_CGW[count.index].TUNNEL2_PSK, null)

#     tags = {
#         Name = "${var.VPN_CON_CGW[count.index].NAME}"
#     }
# }

resource "aws_vpc_peering_connection" "PEER_REQUEST" {
    count = (length(var.PEER_REQUEST) > 0 ? length(var.PEER_REQUEST) : 0)

    vpc_id        = var.PEER_REQUEST[count.index].VPC_ID
    peer_owner_id = var.PEER_REQUEST[count.index].PEER_OWNER_ID
    peer_vpc_id   = var.PEER_REQUEST[count.index].PEER_VPC_ID
    peer_region   = var.PEER_REQUEST[count.index].PEER_REGION_NAME
    auto_accept   = "false"
    
    tags = {
        Name = "${var.PEER_REQUEST[count.index].NAME}"
    }
}

resource "null_resource" "WAIT_FOR_VPC_PEER_REQUEST" {
    count = (length(aws_vpc_peering_connection.PEER_REQUEST) > 0 ? length(aws_vpc_peering_connection.PEER_REQUEST) : 0)
    depends_on = [aws_vpc_peering_connection.PEER_REQUEST]
    
    triggers = {
        attachment_id = aws_vpc_peering_connection.PEER_REQUEST[count.index].id
    }

    provisioner "local-exec" {
        command = <<-EOT
        VPC_PEER_STATUS=$(aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids ${self.triggers.attachment_id} --query 'VpcPeeringConnections[0].Status.Code' --output text --profile thkim-Seoul)
        while [[ $VPC_PEER_STATUS != "active" ]]; do
            sleep 10
            VPC_PEER_STATUS=$(aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids ${self.triggers.attachment_id} --query 'VpcPeeringConnections[0].Status.Code' --output text --profile thkim-Seoul)
        done   
        EOT
        interpreter = ["bash", "-c"]   
        on_failure = continue
    }
}

resource "aws_vpc_peering_connection_options" "REQUEST" {
    count = (length(null_resource.WAIT_FOR_VPC_PEER_REQUEST) > 0 ? length(null_resource.WAIT_FOR_VPC_PEER_REQUEST) : 0)
    depends_on = [ null_resource.WAIT_FOR_VPC_PEER_REQUEST ]

    vpc_peering_connection_id = aws_vpc_peering_connection.PEER_REQUEST[count.index].id
    requester {
        allow_remote_vpc_dns_resolution = true
    }
}

resource "aws_vpc_peering_connection_accepter" "PEER_ACCEPT" {
    count = (length(var.PEER_ACCEPT) > 0 ? length(var.PEER_ACCEPT) : 0)

    vpc_peering_connection_id = var.PEER_ACCEPT[count.index].PEER_ID
    auto_accept               = var.PEER_ACCEPT[count.index].AUTO_ACCEPT
    
    tags = {
        Side = "${var.PEER_ACCEPT[count.index].NAME}"
    }
}

resource "null_resource" "WAIT_FOR_VPC_PEER_ACCEPT" {
    count = (length(aws_vpc_peering_connection_accepter.PEER_ACCEPT) > 0 ? length(aws_vpc_peering_connection_accepter.PEER_ACCEPT) : 0)
    depends_on = [aws_vpc_peering_connection_accepter.PEER_ACCEPT]
    
    triggers = {
        attachment_id = aws_vpc_peering_connection_accepter.PEER_ACCEPT[count.index].id
    }

    provisioner "local-exec" {
        command = <<-EOT
        VPC_PEER_STATUS=$(aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids ${self.triggers.attachment_id} --query 'VpcPeeringConnections[0].Status.Code' --output text --profile=thkim-Singapore)
        while [[ $VPC_PEER_STATUS != "active" ]]; do
            sleep 10
            VPC_PEER_STATUS=$(aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids ${self.triggers.attachment_id} --query 'VpcPeeringConnections[0].Status.Code' --output text --profile=thkim-Singapore)
        done   
        EOT
        interpreter = ["bash", "-c"]   
        on_failure = continue
    }
}

resource "aws_vpc_peering_connection_options" "ACCEPT" {
    count = (length(null_resource.WAIT_FOR_VPC_PEER_ACCEPT) > 0 ? length(null_resource.WAIT_FOR_VPC_PEER_ACCEPT) : 0)
    depends_on = [ null_resource.WAIT_FOR_VPC_PEER_ACCEPT ]

    vpc_peering_connection_id = aws_vpc_peering_connection_accepter.PEER_ACCEPT[count.index].id
    accepter {
        allow_remote_vpc_dns_resolution = true
    }
}




