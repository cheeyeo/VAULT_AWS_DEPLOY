locals {
    snapshot_bucket = "${var.vault_snapshot_bucket}-${random_string.default.result}"
}

resource "aws_s3_bucket" "autosnapshot" {
    bucket = local.snapshot_bucket
}