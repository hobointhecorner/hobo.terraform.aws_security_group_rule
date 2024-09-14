terraform {
  required_version = ">=1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=4.0.0"
    }
  }
}

variable "security_group_id" {
  type        = string
  description = "ID of the security group to which you wish to apply rules"
}

variable "rules" {
  type = map(object({
    type      = string
    protocol  = string
    from_port = number
    to_port   = optional(number)

    # Exactly one of the below must be provided
    security_group   = optional(string)
    cidr_blocks      = optional(list(string))
    ipv6_cidr_blocks = optional(list(string))
    prefix_list_ids  = optional(list(string))
    self             = optional(bool)
  }))

  description = <<-DESC
    One or more security group rules in the following format: `{ some_identifier = { type = ... }, another_identifier = ... }`

    Exactly one of the following properties must be provided per rule: 'security_group', 'cidr_blocks', 'ipv6_cidr_blocks', 'prefix_list_ids', 'self'
  DESC
}

resource "aws_security_group_rule" "rules" {
  for_each = var.rules

  security_group_id = var.security_group_id

  type                     = each.value.type
  protocol                 = each.value.protocol
  from_port                = each.value.from_port
  to_port                  = each.value.to_port != null ? each.value.to_port : each.value.from_port
  source_security_group_id = each.value.security_group
  cidr_blocks              = each.value.cidr_blocks
  ipv6_cidr_blocks         = each.value.ipv6_cidr_blocks
  prefix_list_ids          = each.value.prefix_list_ids
  self                     = each.value.self

  lifecycle {
    precondition {
      condition = length([
        for target in ["security_group", "cidr_blocks", "ipv6_cidr_blocks", "prefix_list_ids", "self"] :
        each.value[target]
        if each.value[target] != null
      ]) == 1

      error_message = "Exactly one of the following must be provided per security group rule: 'security_group', 'cidr_blocks', 'ipv6_cidr_blocks', 'prefix_list_ids', 'self'"
    }

    precondition {
      condition     = each.value.type == "ingress" || each.value.type == "egress"
      error_message = "Value for security group rule type must be either 'ingress' or 'egress'"
    }
  }
}
