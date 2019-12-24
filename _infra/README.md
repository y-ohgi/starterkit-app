starterkit-apply
---

# About
<img src="https://github.com/y-ohgi/starterkit-app/blob/master/_infra/docs/architecture.png?raw=true" />  

# How to Start
## 1. starterkit-infのプロビジョニング
[y-ohgi/starterkit-inf](https://github.com/y-ohgi/starterkit-inf) のプロビジョニングが行われていることを前提にします。

## 2. ECRの作成とイメージのpush
```
$ APP_NAME=<env>-myapp
$ aws ecr create-repository --repository-name ${APP_NAME}
$ $(aws ecr get-login --no-include-email --region ap-northeast-1)
$ ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
$ docker build -t ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/${APP_NAME}:latest .
$ docker push ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/${APP_NAME}:latest
```

## 3. ParameterStoreの作成
```
$ aws ssm put-parameter --name "/${APP_NAME}/db/database" --value "mydatabase" --type String
$ aws ssm put-parameter --name "/${APP_NAME}/db/master_username" --value "myusername" --type String
$ aws ssm put-parameter --name "/${APP_NAME}/db/master_password" --value "mypassword" --type SecureString
```

## 4. Terraformコンテナの立ち上げ
dockerでterraformを起動します。  

Terraformのバージョン差異を解決できればbrewでインストールでもtfenvを使用しても問題ありませんが、今回はバージョンを指定しやすく比較的誰の環境にも入っているであろうdockerを使用します。

```
$ docker run \
    -v $HOME/.aws:/root/.aws \
    -v `pwd`:/code \
    -w /code \
    -it \
    --entrypoint=ash \
    hashicorp/terraform:0.12.18
```

## 5. 初期化処理
workspaceを使用して環境（本番・ステージング等）の設定します。  
サンプルコードでは `prd` ・ `stg` の2環境用意しています。

```
# terraform init -backend-config="bucket=<S3 BUCKET NAME>"
# terraform workspace new <env>
```

## 6. 変数の編集
1. `variables.tf` の `name` を作成するプロダクトに合わせて命名します
    - `name = "${terraform.workspace}-<YOUR PRODUCT NAME>"` 
2. `variables_<env>.tf` の `remote_bucket` へ `starterkit-inf` で使用したS3 bucketを記載します

## 7. プロビジョニング
`plan` でdry-runを実行し、 `apply` でプロビジョニングを実施します。
```
# terraform plan
# terraform apply
```

## 8. 削除
プロビジョニングしたリソースは `destroy` で削除可能です。
```
# terraform destroy
```

# Tips
## デプロイ
初期状態ではECRの `latest` タグを使用するように設定しています。  
本番環境では `latest` を指定するのではなく、サービスのバージョンをタグに指定すると良いでしょう。  
当リポジトリでは `variables.tf` に定義してあるとおり、 `image_tag` でECRのDockerのタグを指定可能です。  

以下は `terraform apply` 時にバージョンを渡す例です。

```
# terraform apply -var 'image_tag=1.0.0'
```

## CDの有効化
CircleCIを使用してCDを行います（CIツールでCDをするなという説はありますが、CDツールを使用するコストと比較して使い分けましょう）。  
GitHub Flowを前提に `.circleci/config.yml` を記載しているので適宜編集とCircleCIへ環境変数の定義を行います。

CircleCIではなくGitHub Actionsやその他のツールでも問題ない無いですが、執筆現在（2019/12）でGitHub EnterpriseにGitHub Actionsが対応していないためCircleCI(Enterprise)を選択しました。

## DBのmigrationの実行
DBのmigrationは複数の手段があります。  
ここではterraformで作成したタスク定義を使用し、VPCやParameterStoreを方法を再利用する方法を紹介します。  
サービスで実際に採用しているmigration方法に合わせて構築ましょう。  
以下はterraformで構築したリソースを再利用してmigrationを実行する例になります（採用する場合はスクリプトに落とすと使いやすいでしょう）。

変数の展開

```
$ APP_NAME="<ENV>-myapp"
$ ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

ECRにmigration用イメージをpush  
今回はマルチステージビルドを行っており、成果物のDockerレイヤーはバイナリだけ配置しています。  
migrationにはmigrateコマンドとmigrationファイルが必要になるため、今回はビルドレイヤーをmigrationへ使用します。

```
$ $(aws ecr get-login --no-include-email --region ap-northeast-1)
$ docker build -t ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/${APP_NAME}:migrate --target build .
$ docker push ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/${APP_NAME}:migrate
```

terraformで作成したタスク定義をJSON形式で取得し、ECRのタグをmigrate用に変更します。

```
$ TASK_DEFINITION=$(aws ecs describe-task-definition --task-definition=${APP_NAME}| sed 's/:latest/:migrate/')
$ aws ecs register-task-definition \
    --container-definitions="$(echo $TASK_DEFINITION | jq '.taskDefinition.containerDefinitions')" \
    --execution-role-arn=$(echo $TASK_DEFINITION | jq -r '.taskDefinition.executionRoleArn') \
    --cpu=$(echo $TASK_DEFINITION | jq -r '.taskDefinition.cpu') \
    --memory=$(echo $TASK_DEFINITION | jq -r '.taskDefinition.memory') \
    --family=${APP_NAME}-migrate \
    --requires-compatibilities=FARGATE \
    --network-mode=awsvpc
```

作成したタスク定義を使用してmigrationを実行

```
$ SERVICE=$(aws ecs describe-services \
              --cluster ${APP_NAME} \
              --service ${APP_NAME} \
              --output json)
$ SUBNET=$(echo ${SERVICE} | jq -rc '.services[0].networkConfiguration.awsvpcConfiguration.subnets[0]')
$ SG_IDS=$(echo ${SERVICE} | jq -rc '.services[0].networkConfiguration.awsvpcConfiguration.securityGroups | join(",")')
$ aws ecs run-task \
    --override='{"containerOverrides":[{"name":"main","command":["sh","-c","migrate -path=db/migrations -database \"mysql://${DB_USER}:${DB_PASSWORD}@tcp(${DB_HOST}:3306)/${DB_DATABASE}\" up"]}]}' \
    --cluster ${APP_NAME} \
    --task-definition=${APP_NAME}-migrate \
    --network-configuration="awsvpcConfiguration={subnets=[${SUBNET}],securityGroups=[$SG_IDS]}" \
    --launch-type="FARGATE"
```

最後にCloudWatch Logsでmigrationが実行されたことを確認します。
