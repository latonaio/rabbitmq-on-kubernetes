# rabbitmq-on-kubernetes

## 概要  

rabbitmq-on-kubernetes は、RabbitMQ を設定し、Kubernetes上 の pod として動かすために必要な、初期化スクリプト と deployment.yml です。

## rabbitmq-on-kubernetes を使用したエッジコンピューティングアーキテクチャの例  
![フローチャート図](doc/omotebako_architecture_20211104.drawio.png)  

## AION における RabbitMQ の 役割  

AION において、RabbitMQ は、以下の領域で、それぞれの役割を果たします。   

・マイクロサービス間のメッセージのやり取り（[aion-service-definitions](https://github.com/latonaio/aion-service-definitions)で定義）：  
  各マイクロサービスは、RabbitMQ に、メッセージとして、処理結果のJSONと、宛先(=次のマイクロサービス)等のメタデータを渡します。  
  RabbitMQは、当該宛先で指定された次のマイクロサービスに、そのメッセージを渡します。  
  次のマイクロサービスは、RabbitMQ から当該メッセージを受け取り、必要なデータを読み取り、処理を行います。（次のマイクロサービスは常時待機状態で、イベントドリブンで処理が行われます）  
  このように、RabbitMQ は、各マイクロサービス間のメッセージブローカーの役割を果たします。 
  
## rabbitmq-on-kubernetesにおけるAI/IoT環境のためのデータパイプライン    
下記の図は、AIONプラットフォームにおけるAI/IoT環境のためのデータパイプラインのアーキテクチャです。   
rabbitmq-on-kubernetes は、AI/IoT環境のデータパイプラインのコアとして、マイクロサービス間のメッセージング処理を担います。  
各マイクロサービスとRabbitMQ間における、メタデータや処理結果のJSON等の受け渡しは、当該マイクロサービスに対して、aion-service-definisions で定義された RabbitMQ のための設定をすることで行われます。  
データパイプラインにおけるマイクロサービス化された RabbitMQ は、他のコンポーネントと疎結合されており、軽量なメッセージングアーキテクチャとして、AI / IoT ランタイムの I/Oに対して高速で安定的なシステム環境の構築を実現します。 

![data-pipeline](doc/data_pipeline.drawio.png)  

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

### サンプルのキュー定義  
サンプルのキュー定義として、init-queues.shに以下のキュー名一覧が記載されています。  
```
# キュー名一覧
queues=(
azure-face-api-identifier-kube-queue
azure-face-api-registrator-kube-queue
get-response-of-face-api-kube-queue
register-face-to-guest-table-kube-queue
send-data-to-azure-iot-hub-queue
slack-message-client-kube-queue
avis-client-kube-queue
)
```

サンプルのキュー定義のうち、エッジクラスター（1エッジ端末内を含む）内部用のキューとエッジクラスター外部用のキューを分類すると、以下のようになります。   

##### エッジクラスター内部用キューの例  

* azure-face-api-identifier-kube-queue  
* azure-face-api-registrator-kube-queue  
* get-response-of-face-api-kube-queue  
* register-face-to-guest-table-kube-queue  
    
##### エッジクラスター外部用キューの例  
      
* send-data-to-azure-iot-hub-queue：エッジ側からAzure IoT Hubにメッセージを送信するためのキュー （※該当マイクロサービスについては、[こちら](https://github.com/latonaio/send-data-to-azure-iot-hub) を参照してください）
* slack-message-client-kube-queue：エッジ側からSlackにメッセージを送信するためのキュー （※該当マイクロサービスについては、[こちら](https://github.com/latonaio/slack-message-client-kube) を参照してください）
* avis-client-kube-queue：Avis のデータ収集元として、エッジ端末等内においてデータを維持するためのキュー （※Avis については、[avis](https://github.com/latonaio/avis)、[avis-electron](https://github.com/latonaio/avis-electron) を参照してください）

## RabbitMQ の導入  

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
        image: rabbitmq:3.9.11-management-alpine
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

## RabbitMQ の ランタイム別 クライアントライブラリ  
AION において RabbitMQ を正しく動作させるには、本レポジトリのリソースとは別に、次のランタイム別のクライアントライブラリが必要です。 
マイクロサービスのランタイムの特性に応じて、必要なライブラリをクローンしてください。  

* [rabbitmq-golang-client](https://github.com/latonaio/rabbitmq-golang-client)
* [rabbitmq-nodejs-client](https://github.com/latonaio/rabbitmq-nodejs-client)
* [rabbitmq-python-client](https://github.com/latonaio/rabbitmq-python-client)
* [rabbitmq-c-client](https://github.com/latonaio/rabbitmq-c-client)

## マイクロサービスにおける RabbitMQ との 疎通 のための Main ソースコードの書き方  
AIONでは、マイクロサービスにおける RabbitMQ との 疎通を、マイクロサービス の Main ソースコードに書く必要があります。  
マイクロサービスにおける RabbitMQ との 疎通のための Main ソースコード の書き方 の サンプルとして、例えば、azure-face-api-registrator-kube の main.py において、次のように書かれています。  
```
# RabbitMQ用モジュール
from rabbitmq_client import RabbitmqClient

async def main():
    init_logger()

    # RabbitMQの接続情報
    rabbitmq_url = os.environ['RABBITMQ_URL']
    # キューの読み込み元
    queue_origin = os.environ['QUEUE_ORIGIN']
    # キューの書き込み先
    queue_to = os.environ['QUEUE_TO']

    try:
        mq_client = await RabbitmqClient.create(rabbitmq_url, {queue_origin}, {queue_to})
    except Exception as e:
        logger.error({
            'message': 'failed to connect rabbitmq!',
            'error': str(e),
            'queue_origin': queue_origin,
            'queue_to': queue_to,
        })
        # 本来 sys.exit を使うべきだが、効かないので
        os._exit(1)

    logger.info('create mq client')

    async for message in mq_client.iterator():
        try:
            async with message.process():
                logger.info({
                    'message': 'received from: ' + message.queue_name,
                    'params': message.data,
                })
                guest_id = message.data.get('guest_id')
                filepath = message.data.get('face_image_path')
                output_path = message.data.get('output_data_path')

                fr = FaceRecognition()
                person_list = fr.getPersonList()
                ids = len(person_list)
                person = fr.getFaceAttributes(filepath)
                # 一番大きい顔を選ぶ
                attributes = {
                    'gender': str(person[0].face_attributes.gender).lstrip('Gender.'),
                    'age': str(person[0].face_attributes.age)
                }
                now = datetime.datetime.now()
                tmp_file = os.path.join(output_path, now.strftime('%Y%m%d_%H%M%S') + '.jpg')
                image_data = Image.open(filepath)
                image_data.crop(getRectangle(person[0].face_rectangle)).save(tmp_file, quality=95)
                name = now.strftime('%Y%m%d_%H%M%S')
                person_id = fr.createPerson(ids)
                fr.setPersonImage(person_id, tmp_file, person[0].face_rectangle)
                fr.train()
                os.remove(tmp_file)

                payload = {
                    'result': True,
                    'filepath': filepath,
                    'guest_id': guest_id,
                    'face_id_azure': str(person_id),
                    'attributes': attributes,
                }
                logger.debug({
                    'message': 'send message',
                    'params': payload,
                })
                await mq_client.send(queue_to, payload)
                logger.info('sent message')
        except Exception as e:
            logger.error({
                'message': 'error with processing message',
                'error': str(e),
            })

if __name__ == '__main__':
    asyncio.run(main())
```

## マイクロサービスにおける RabbitMQ の Kubernetes yml 設定ファイル    
AION では、マイクロサービス毎に、RabbitMQ に関する Kubernetes ymlファイルの内容を 定義する必要があります。  
当該 yml ファイルでは、QUEUE の生成マイクロサービスの名前(=自マイクロサービス自身、QUEUE_ORIGIN)、QUEUE を送信するマイクロサービスの名前(QUEUE_TO)を記述します。  
QUEUE_TO は複数、定義することができます。  
例えば、azure-face-api-registrator-kube の services.yml において、次のように書かれています。  
```
azure-face-api-registrator-kube:
  startup: yes
  always: yes
  scale: 1
  env:
    RABBITMQ_URL: amqp://guest:guest@rabbitmq:5672/xxxxxxxx
    QUEUE_ORIGIN: azure-face-api-registrator-kube-queue
    QUEUE_TO: register-face-to-guest-table-kube-queue
```