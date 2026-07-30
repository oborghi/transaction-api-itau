resource "aws_docdb_cluster" "main" {
  cluster_identifier     = "${var.app_name}_docdb"
  master_username        = var.db_master_username
  master_password        = var.db_master_password
  db_subnet_group_name   = aws_docdb_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.docdb.id]
  skip_final_snapshot    = var.environment != "production"
  storage_encrypted      = true

  tags = { Name = "${var.app_name}_docdb" }
}

resource "aws_docdb_cluster_instance" "main" {
  count              = var.environment == "production" ? 2 : 1
  identifier         = "${var.app_name}_docdb_${count.index}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.db_instance_class

  tags = { Name = "${var.app_name}_docdb_${count.index}" }
}

resource "aws_docdb_subnet_group" "main" {
  name       = "${var.app_name}_docdb_subnet"
  subnet_ids = aws_subnet.private_data[*].id

  tags = { Name = "${var.app_name}_docdb_subnet" }
}

resource "aws_security_group" "docdb" {
  name_prefix = "${var.app_name}_docdb_"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.app_name}_docdb_sg" }

  lifecycle {
    create_before_destroy = true
  }
}
