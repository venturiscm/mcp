
provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.firewall.network.region}"
}

resource "aws_security_group_rule" "firewall" {
    security_group_id = "${var.firewall.security_group}"
    type = "${var.mode}"
    from_port = "${var.from_port}"
    to_port = "${var.to_port}"
    protocol = "${var.protocol}"
    cidr_blocks = "${var.cidrs}"
}