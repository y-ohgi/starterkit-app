terraform {
  required_version = ">=0.12"
  backend "s3" {
    #FIXME: 使用する目的に応じてkeyの命名を変更してください。 e.g. "api.tfstate"
    key    = "app.tfstate"
    region = "ap-northeast-1"
  }
}

provider "aws" {
  version = "~> 2.42"
  region  = "ap-northeast-1"
}

data "aws_caller_identity" "self" {}

data "terraform_remote_state" "inf" {
  backend = "s3"

  workspace = terraform.workspace

  config = {
    # FIXME: "starterkit-inf" リポジトリで使用したtfstate名を入力してください。デフォルトは"inf.tfstate"です。
    key    = "inf.tfstate"
    region = "ap-northeast-1"
    bucket = local.workspace["remote_bucket"]
  }
}

locals {
  # プロビジョニング対象のアカウントID
  account_id = data.aws_caller_identity.self.account_id

  # ECS Serviceに登録するVPC
  vpc_id = data.terraform_remote_state.inf.outputs.vpc_id

  # ECS Serviceに登録するSubnet
  subnets = data.terraform_remote_state.inf.outputs.private_subnets

  # ECS Serviceと疎通させるALBのListener
  alb_https_listener_arn = data.terraform_remote_state.inf.outputs.alb_https_listener_arn

  # ECS Serviceを配置するECSクラスター名
  ecs_cluster_name = data.terraform_remote_state.inf.outputs.ecs_cluster_name

  # ECS Serviceの前段に置くALB
  alb_sg_id = data.terraform_remote_state.inf.outputs.alb_sg_id
}

#########################
# Security Group
#########################
module "sg_app" {
  source = "./modules/securitygroup"

  vpc_id = local.vpc_id

  name = "${local.name}"
  tags = local.tags

  ingress_with_security_group_rules = [
    {
      "source_security_group_id" : local.alb_sg_id,
      "port" : "1323"
    }
  ]
}

module "sg_mysql" {
  source = "./modules/securitygroup"

  vpc_id = local.vpc_id

  name = "${local.name}-mysql"
  tags = local.tags

  ingress_with_security_group_rules = [
    {
      "source_security_group_id" : module.sg_app.sg_id,
      "port" : "3306"
    }
  ]
}

#########################
# Aurora MySQL
#########################
data "aws_ssm_parameter" "database_name" {
  name = "/${local.name}/db/database"
}

data "aws_ssm_parameter" "master_username" {
  name = "/${local.name}/db/master_username"
}

data "aws_ssm_parameter" "master_password" {
  name = "/${local.name}/db/master_password"
}

module "mysql" {
  source = "./modules/aurora-mysql"

  name = local.name
  tags = local.tags

  subnets         = local.subnets
  security_groups = [module.sg_mysql.sg_id]
  database_name   = data.aws_ssm_parameter.database_name.value
  master_username = data.aws_ssm_parameter.master_username.value
  master_password = data.aws_ssm_parameter.master_password.value
}

#########################
# ECS Service
#########################
data "template_file" "container_definitions" {
  template = "${file("container_definitions.json")}"

  vars = {
    account_id = local.account_id
    name       = local.name
    region     = "ap-northeast-1"

    image_tag = var.image_tag

    db_port     = "3306"
    db_host     = module.mysql.endpoint
    db_user     = data.aws_ssm_parameter.master_username.value
    db_password = "/${local.name}/db/master_password"
    db_database = data.aws_ssm_parameter.database_name.value
  }
}

module "ecs" {
  source = "./modules/ecs-service"

  name = local.name
  tags = local.tags

  account_id             = local.account_id
  alb_https_listener_arn = local.alb_https_listener_arn
  container_definitions  = data.template_file.container_definitions.rendered
  ecs_cluster_name       = local.ecs_cluster_name
  port                   = "1323"
  security_groups        = [module.sg_app.sg_id]
  subnets                = local.subnets
  vpc_id                 = local.vpc_id
}
