#!/bin/bash

####################
## 設定項目
####################

# ユーザ名
user=sample_user

# パスワード
passwd=sample_pass

# バーチャルホスト名
vhost=sample_vhost

# キュー名一覧
queues=(
	sample-queue-1
	sample-queue-2
)



default_user=guest
default_vhost=/
pod=$(kubectl get pod | grep -E '^rabbitmq-[0-9a-f]+-[0-9a-z]+ ' | sed -E 's/^([^ ]+) .*$/\1/')

rabbitmqctl() {
	kubectl exec "$pod" -it -- rabbitmqctl "$@"
}

rabbitmqadmin() {
	kubectl exec "$pod" -it -- rabbitmqadmin --username="$user" --password="$passwd" "$@"
}

# pod 内で RabbitMQ が起動するのを待つ
rabbitmqctl await_startup

# デフォルトユーザの削除
rabbitmqctl delete_user "$default_user"

# ユーザ作成
if rabbitmqctl add_user "$user" "$passwd"; then
	# 管理権限追加
	rabbitmqctl set_user_tags "$user" administrator

	# 既存のバーチャルホスト全部に対して
	rabbitmqctl list_vhosts --no-table-headers --quiet | while IFS= read -r v && v=${v%$'\r'}; do
		# アクセス権の設定
		rabbitmqctl set_permissions -p "$v" "$user" ".*" ".*" ".*" < /dev/null 2> /dev/null
	done
fi

# 一旦 virtualhost ごと削除して再定義
# (キューを一旦全部消すため)
rabbitmqadmin delete vhost name="$vhost"
rabbitmqadmin declare vhost name="$vhost"

# キューの定義
for queue in "${queues[@]}"; do
	rabbitmqadmin declare queue --vhost="$vhost" name="$queue" durable=true
done
