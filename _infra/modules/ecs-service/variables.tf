variable "name" {
  description = "リソースの識別子として使用する名前"
  type        = string
}

variable "tags" {
  description = "リソースに付与するタグ"
  default     = {}
}

variable "account_id" {
  description = "プロビジョニング対象のAWSアカウントID"
  type        = string
}

variable "vpc_id" {
  description = "ターゲットグループを作成するVPCのID"
  type        = string
}

variable "alb_https_listener_arn" {
  description = "ECS Serviceと疎通させるALBのListener arn情報"
  type        = string
}

variable "port" {
  description = "トラフィックを受け付けるポート"
  default     = "80"
}

variable "container_definitions" {
  description = "JSONで記述されたタスク定義"
  type        = string
}

variable "task_cpu" {
  description = "タスクのCPU"
  default     = 256
}

variable "task_memory" {
  description = "タスクのメモリ"
  default     = 512
}

variable "ecs_cluster_name" {
  description = "ECS Serviceを配置するECSクラスター名"
  type        = string
}

variable "service_desired_count" {
  description = "ECS Serviceの初回タスク起動数"
  default     = 2
}

variable "subnets" {
  description = "ECS Serviceを配置するSubnet"
  type        = list
}

variable "security_groups" {
  description = "ECS Serviceに登録するセキュリティグループ一覧 e.g. ['sg-edcd9784','sg-edcd9785']"
  type        = list
}
