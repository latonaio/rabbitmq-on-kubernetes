#!/bin/bash

####################
## 設定項目
####################

# ユーザ名
user=guest

# パスワード
passwd=guest

# バーチャルホスト名
vhost=sap-test

# キュー名一覧
queues=(
	sap-api-integrations-classification-reads-rmq-kube
	sap-api-integrations-characteristic-reads-rmq-kube
	sap-api-integrations-bank-master-reads-rmq-kube
	sap-api-integrations-business-partner-reads-rmq-kube
	sap-api-integrations-product-group-reads-rmq-kube
	sap-api-integrations-product-master-reads-rmq-kube
	sap-api-integrations-product-master-class-reads-rmq-kube
	sap-api-integrations-batch-master-record-reads-rmq-kube
	sap-api-integrations-material-stock-reads-rmq-kube
	sap-api-integrations-reservation-document-reads-rmq-kube
	sap-api-integrations-inbound-delivery-reads-rmq-kube
	sap-api-integrations-material-document-reads-rmq-kube
	sap-api-integrations-physical-inventory-doc-reads-rmq-kube
	sap-api-integrations-warehouse-resource-reads-rmq-kube
	sap-api-integrations-warehouse-available-stock-reads-rmq-kube
	sap-api-integrations-business-partner-reads-customer-rmq-kube
	sap-api-integrations-credit-mgmt-master-reads-rmq-kube
	sap-api-integrations-customer-material-reads-rmq-kube
	sap-api-integrations-sales-pricing-reads-rmq-kube	
	sap-api-integrations-sales-inquiry-reads-rmq-kube
	sap-api-integrations-sales-quotation-reads-rmq-kube
	sap-api-integrations-sales-order-reads-rmq-kube
	sap-api-integrations-sales-contract-reads-rmq-kube
	sap-api-integrations-sales-scheduling-agreement-reads-rmq-kube
	sap-api-integrations-outbound-delivery-reads-rmq-kube
	sap-api-integrations-customer-return-reads-rmq-kube
	sap-api-integrations-billing-document-reads-rmq-kube
	sap-api-integrations-credit-memo-request-reads-rmq-kube
	sap-api-integrations-debit-memo-request-reads-rmq-kube
	sap-api-integrations-business-partner-reads-supplier-rmq-kube
	sap-api-integrations-pur-source-list-reads-rmq-kube
	sap-api-integrations-pur-info-record-reads-rmq-kube
	sap-api-integrations-purchase-requisition-reads-rmq-kube
	sap-api-integrations-purchase-order-reads-rmq-kube
	sap-api-integrations-purchase-contract-reads-rmq-kube
	sap-api-integrations-purchase-scheduling--reads-rmq-kube
	sap-api-integrations-supplier-invoice-reads-rmq-kube
	sap-api-integrations-inbound-delivery-reads-rmq-kube
	sap-api-integrations-bill-of-material-reads-rmq-kube
	sap-api-integrations-bom-where-used-list-reads-rmq-kube
	sap-api-integrations-work-center-reads-rmq-kube
	sap-api-integrations-production-routing-reads-rmq-kube
	sap-api-integrations-planned-independent-req-reads-rmq-kube
	sap-api-integrations-planned-order-reads-rmq-kube
	sap-api-integrations-production-order-reads-rmq-kube
	sap-api-integrations-production-order-conf-reads-rmq-kube
	sap-api-integrations-master-recipe-reads-rmq-kube
    sap-api-integrations-process-order-reads-rmq-kube
	sap-api-integrations-process-order-conf-reads-rmq-kube
    sap-api-integrations-inspection-plan-reads-rmq-kube
	sap-api-integrations-quality-info-record-reads-rmq-kube
	sap-api-integrations-functional-location-reads-rmq-kube
	sap-api-integrations-equipment-master-reads-rmq-kube
	sap-api-integrations-maintenance-bom-reads-rmq-kube
	sap-api-integrations-maintenance-plan-reads-rmq-kube
	sap-api-integrations-maintenance-item-reads-rmq-kube
	sap-api-integrations-maintenance-notification-reads-rmq-kube
	sap-api-integrations-maintenance-order-reads-rmq-kube
	sap-api-integrations-maintenance-order-conf-reads-rmq-kube
	sap-api-integrations-defect-reads-rmq-kube
	sap-api-integrations-maintenance-task-list-reads-rmq-kube
    sap-api-integrations-measuring-point-reads-rmq-kube
	sap-api-integrations-measurement-document-reads-rmq-kube
	sap-api-integrations-service-order-reads-rmq-kube
	sap-api-integrations-service-confirmation-reads-rmq-kube
	sap-sql-update-kube
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

