variable "image_tag" {
  description = "デプロイ時に用いるコンテナのtag"
  default     = "latest"
}

locals {
  workspaces = {
    default = local.stg
    stg     = local.stg
    prd     = local.prd
  }

  workspace = local.workspaces[terraform.workspace]

  # FIXME: アプリケーションに応じて命名を変更してください。 e.g. "${terraform.workspace}-blog"
  name = "${terraform.workspace}-myapp"

  tags = {
    Name        = local.name
    Terraform   = "true"
    Environment = terraform.workspace
  }
}
