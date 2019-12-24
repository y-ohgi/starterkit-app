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

## 3. Terraformコンテナの立ち上げ
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

## 4. 初期化処理
workspaceを使用して環境（本番・ステージング等）の設定します。  
サンプルコードでは `prd` ・ `stg` の2環境用意しています。

```
# terraform init -backend-config="bucket=<S3 BUCKET NAME>"
# terraform workspace new <env>
```

## 5. 変数の編集
1. `variables.tf` の `name` を作成するプロダクトに合わせて命名します
    - `name = "${terraform.workspace}-<YOUR PRODUCT NAME>"` 
2. `variables_<env>.tf` の `remote_bucket` へ `starterkit-inf` で使用したS3 bucketを記載します

## 6. プロビジョニング
`plan` でdry-runを実行し、 `apply` でプロビジョニングを実施します。
```
# terraform plan
# terraform apply
```

## 7. 削除
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
