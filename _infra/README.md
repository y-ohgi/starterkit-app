# How to Start
## 1. starterkit-infのプロビジョニング
[y-ohgi/starterkit-inf](https://github.com/y-ohgi/starterkit-inf) のプロビジョニングが行われていることを前提にします。

## 2. ECRの作成とイメージのpush
```
$ aws ecr create-repository --repository-name api
$ $(aws ecr get-login --no-include-email --region ap-northeast-1)
$ ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
$ docker build -f docker/nginx/Dockerfile -t ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/app:latest .
$ docker push ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/app:latest
```

## 3. ParameterStoreの作成
```
$ APP_NAME=<env>-myapp
$ aws ssm put-parameter --name "/${APP_NAME}/db/database" --value "mydatabase" --type String
$ aws ssm put-parameter --name "/${APP_NAME}/db/username" --value "myusername" --type String
$ aws ssm put-parameter --name "/${APP_NAME}/db/password" --value "mypassword" --type SecureString
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
2. Route53のホストゾーンにドメインを用意し、 `variables_<env>.tf` の `domains` へ使用するドメインを記載します。  
    - `domains` は `,` 区切りで複数のドメインを記載することが可能です。

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
