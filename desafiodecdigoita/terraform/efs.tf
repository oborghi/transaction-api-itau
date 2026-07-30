# ==========================================
# EFS for MongoDB persistent storage
# ==========================================
# Free Tier: 25GB EFS included
# Suportado pelo Fargate (platform >= 1.4.0)
# Dados do MongoDB sobrevivem a restart do container
# ==========================================

# Security Group para EFS (NFS port 2049)
resource "aws_security_group" "efs" {
  name_prefix = "${var.app_name}_efs_"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.mongodb.id]
    description     = "NFS from MongoDB ECS tasks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.app_name}_efs_sg" }
  lifecycle { create_before_destroy = true }
}

# EFS Filesystem
resource "aws_efs_file_system" "mongodb" {
  creation_token = "${var.app_name}-mongodb-data"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = { Name = "${var.app_name}_mongodb_efs" }
}

# EFS Mount Targets (one per subnet)
resource "aws_efs_mount_target" "mongodb" {
  count           = length(var.availability_zones)
  file_system_id  = aws_efs_file_system.mongodb.id
  subnet_id       = aws_subnet.public[count.index].id
  security_groups = [aws_security_group.efs.id]
}

# EFS Access Point for MongoDB (permissão 0777 - world writable)
# Não forçamos uid/gid para evitar conflitos de permissão com o container
resource "aws_efs_access_point" "mongodb" {
  file_system_id = aws_efs_file_system.mongodb.id

  posix_user {
    uid = 0
    gid = 0
  }

  root_directory {
    path = "/data/db"
    creation_info {
      owner_uid   = 0
      owner_gid   = 0
      permissions = "0777"
    }
  }

  tags = { Name = "${var.app_name}_mongodb_efs_ap" }
}
