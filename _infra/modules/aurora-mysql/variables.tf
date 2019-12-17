variable "name" {
  description = "リソースの識別子として使用する名前"
  type        = string
}

variable "tags" {
  description = "リソースに付与するタグ"
  default     = {}
}

variable "subnets" {
  description = "Aurora MySQLを配置するSubnet"
  type        = list
}

variable "security_groups" {
  description = "Auroraへ登録するセキュリティグループ一覧 e.g. ['sg-edcd9784','sg-edcd9785']"
  type        = list
}

variable "database_name" {
  description = "デフォルトで作成されるデータベース名"
  type        = string
}

variable "master_username" {
  description = "デフォルトで作成されるマスターユーザーのマスタユーザー名"
  type        = string
}

variable "master_password" {
  description = "デフォルトで作成されるマスターユーザーのパスワード"
  type        = string
}
