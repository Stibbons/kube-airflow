.PHONY: test

NAMESPACE ?= airflow-dev
CHART_LOCATION ?= airflow/
HELM_RELEASE_NAME ?= airflow
HELM_VALUES_FILE ?= ""

ifeq ($(HELM_VALUES_FILE), "")
	HELM_VALUES_ARG=
else
	HELM_VALUES_ARG=-f $(HELM_VALUES_FILE)
endif

reset-minikube:
	# Force redownload of latest minikube ISO
	minikube delete
	minikube start

minikube-start:
	minikube start

minikube-stop:
	minikube stop

minikube-restart: minikube-start

minikube-dashboard:
	minikube dashboard

minikube-browse-web:
	minikube service $(HELM_RELEASE_NAME)-web -n $(NAMESPACE)

minikube-url-web:
	minikube service $(HELM_RELEASE_NAME)-web -n $(NAMESPACE) --url

minikube-browse-flower:
	minikube service $(HELM_RELEASE_NAME)-flower -n $(NAMESPACE)

minikube-url-flower:
	minikube service $(HELM_RELEASE_NAME)-flower -n $(NAMESPACE) --url

helm-init:
	helm init --upgrade

helm-install-traefik:
	minikube addons enable ingress
	helm upgrade --install \
		--namespace kube-system \
		--set dashboard.enabled=true \
		ingress \
		stable/traefik

helm-status:
	helm status $(HELM_RELEASE_NAME)

helm-upgrade: helm-upgrade-dep helm-upgrade-install

helm-upgrade-dep:
	helm dep build $(CHART_LOCATION)

helm-upgrade-install:
	helm upgrade --install \
		--wait\
		--debug \
		--namespace=$(NAMESPACE) \
		$(HELM_VALUES_ARG) \
		$(HELM_RELEASE_NAME) \
		$(CHART_LOCATION)

test:
	make helm-upgrade HELM_VALUES_FILE=./test/testvalues.yaml

helm-lint:
	helm lint \
		$(CHART_LOCATION) \
		--namespace=$(NAMESPACE) \
		--debug \
		$(HELM_VALUES_ARG)

helm-delete:
	helm delete --purge \
		$(HELM_RELEASE_NAME)

wait:
	sleep 60

minikube-full-test: minikube-restart wait helm-init helm-install-traefik helm-delete test

kubectl-get-services:
	kubectl get services --namespace $(NAMESPACE)

kubectl-list-pods:
	kubectl get po -a --namespace $(NAMESPACE)
