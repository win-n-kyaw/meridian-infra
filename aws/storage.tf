resource "aws_ebs_volume" "prometheus_data" {
  availability_zone = aws_instance.ops.availability_zone
  size              = var.prometheus_volume_size_gb
  type              = "gp3"

  tags = merge(local.common_tags, {
    Name = "prometheus-data"
    role = "monitoring"
  })
}

resource "aws_volume_attachment" "prometheus_data" {
  device_name = var.prometheus_volume_device_name
  volume_id   = aws_ebs_volume.prometheus_data.id
  instance_id = aws_instance.ops.id
}
