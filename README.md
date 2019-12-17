starterkit-inf
---

[y-ohgi/starterkit](https://github.com/y-ohgi/starterkit) が前提になります。

# About
このリポジトリでは [y-ohgi/starterkit-inf](https://github.com/y-ohgi/starterkit-inf) で構築したリソースの上にアプリケーションの構築を行います。  
`_infra` がこのリポジトリの本体で、アプリケーションの実装は言語（Rails・Golang・Scala）や領域（サーバーサイド・フロントエンド）を問いません。  

今回は「DBへの疎通を行う」サンプルとしてGolangでミニマルなサンプルコードを用意しました。

# How to Use
```
$ docker-compose up
```

# Migrate
DBのマイグレーションには [golang-migrate/migrate](https://github.com/golang-migrate/migrate) を使用する。  

## migrate
マイグレーションを実行する
```
$ docker run \
  --network=starterkit-app_default \
  -v `pwd`/db/migrations:/migrations \
  migrate/migrate \
  -path=/migrations \
  -database "mysql://root:@tcp(db:3306)/echodb" \
  up
```

## create
新しくDDLを記述する場合
```
$ docker run \
  -v `pwd`/db/migrations:/migrations \
  migrate/migrate \
  create \
  -ext sql \
  -dir /migrations \
  -seq <migration_name>
```
