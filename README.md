# rabbitmq-on-kubernetes

## 概要  

rabbitmq-on-kubernetes は、RabbitMQ を設定し、Kubernetes上 の pod として動かすために必要な、初期化スクリプト と deployment.yml です。

# rabbitmq-on-kubernetes を使用したエッジコンピューティングアーキテクチャ  
![フローチャート図](doc/omotebako_architecture_20211016.drawio.png)  

## RabbitMQ の初期設定  

サンプルの初期化スクリプト `init-queues.sh` を用意しています。必要に応じて設定部分などを書き換え実行してください。

初期化スクリプトでは以下の操作を行います:

* 管理ユーザをデフォルトユーザから新しいユーザに変更
	* デフォルトユーザ (guest) の削除
	* 新規ユーザの作成
	* 新規ユーザに管理権限を付与
	* 既存のバーチャルホスト全てへのアクセス権限を付与
* バーチャルホストの新規作成
* キューの作成

## Rabbit MQ の導入  

`kubectl apply -f deployment.yml` コマンドを利用してください。

必要に応じて yml 内の設定などを変更してください。

* RabbitMQ のデータの永続化先: `rabbitmq-data` の `hostPath`.`path` 部分
* RabbitMQ のバージョン: `image: rabbitmq-[バージョン]-management-alpine` の部分

特に問題がない場合、導入時点での最新版 RabbitMQ のご利用をおすすめします。[こちら](https://rabbitmq.com/download.html)で最新バージョンを確認できます。


## RabbitMQ のデプロイ・稼働  
[aion-core-manifests](https://github.com/latonaio/aion-core-manifests)の template/bases/rabbitmq の deployment.yml に RabbitMQ をデプロイするために必要なyamlファイルが配置されています。    

ymlファイル（deployment.yml）の中身  
```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    run: rabbitmq
  name: rabbitmq
spec:
  replicas: 1
  selector:
    matchLabels:
      run: rabbitmq
  strategy:
    rollingUpdate:
  template:
    metadata:
      labels:
        run: rabbitmq
    spec:
      hostname: rabbitmq
      containers:
      - name: rabbitmq
        tty: true
        image: rabbitmq:3.9.5-management-alpine
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 5672
        volumeMounts:
        - name: rabbitmq-data
          mountPath: /var/lib/rabbitmq/mnesia
      volumes:
      - name: rabbitmq-data
        hostPath:
          path: /var/lib/aion/default/Data/rabbitmq
---
apiVersion: v1
kind: Service
metadata:
  labels:
    run: rabbitmq
  name: rabbitmq
spec:
  selector:
    run: rabbitmq
  type: NodePort
  ports:
  - name: rabbitmq-node
    port: 5672
    protocol: TCP
    targetPort: 5672
    nodePort: 32094
  - name: rabbitmq-mgmt
    port: 15672
    protocol: TCP
    targetPort: 15672
    nodePort: 32095
```

## その他の RabbitMQ に関する設定

`http://[端末の IP アドレス]:32095/` に Web UI がありますので、設定したユーザ名とパスワードでログインしてください。  


## RabbitMQ への接続（Kubernetes内から、外部から）

以下のように URL を指定して接続します。  

なお、バーチャルホスト名に記号を含む場合は、URL エンコードが必要となります。  

例: デフォルトバーチャルホスト `/` にアクセスする場合: `%2F`  


### Kubernetes 内から

`amqp://[ユーザ名]:[パスワード]@rabbitmq:5672/[バーチャルホスト名]` で接続できます。   


### 外部のホストから

`amqp://[ユーザ名]:[パスワード]@[端末の IP アドレス]:32094/[バーチャルホスト名]` で接続できます。  