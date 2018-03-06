.PHONY: test

MINIKUBE_PROFILE=airflow
NAMESPACE ?= airflow-dev
CHART_LOCATION ?= airflow/
HELM_RELEASE_NAME ?= airflow
HELM_VALUES_FILE ?= ""
## Set HELM_RECREATE_PODS to 'yes' to force pod recreation
HELM_RECREATE_PODS ?= no

ifeq ($(HELM_VALUES_FILE), "")
	HELM_VALUES_ARG=
else
	HELM_VALUES_ARG=-f $(HELM_VALUES_FILE)
endif

ifeq ($(HELM_RECREATE_PODS), "yes")
	HELM_RECREATE_PODS_ARG=
else
	HELM_RECREATE_PODS_ARG=--recreate-pods
endif

reset-minikube:
	# Force redownload of latest minikube ISO
	minikube -p $(MINIKUBE_PROFILE) delete
	minikube -p $(MINIKUBE_PROFILE) start

minikube-start:
	minikube -p $(MINIKUBE_PROFILE) start \
		--memory 8192

minikube-stop:
	minikube -p $(MINIKUBE_PROFILE) stop

minikube-restart: minikube-start helm-init

minikube-dashboard:
	minikube -p $(MINIKUBE_PROFILE) dashboard

minikube-service-list:
	minikube -p $(MINIKUBE_PROFILE) service list

minikube-browse-web:
	minikube -p $(MINIKUBE_PROFILE) service $(HELM_RELEASE_NAME)-web -n $(NAMESPACE)

minikube-url-web:
	minikube -p $(MINIKUBE_PROFILE) service $(HELM_RELEASE_NAME)-web -n $(NAMESPACE) --url

minikube-browse-flower:
	minikube -p $(MINIKUBE_PROFILE) service $(HELM_RELEASE_NAME)-flower -n $(NAMESPACE)

minikube-url-flower:
	minikube -p $(MINIKUBE_PROFILE) service $(HELM_RELEASE_NAME)-flower -n $(NAMESPACE) --url

helm-init:
	helm init --upgrade --wait --debug

helm-install-traefik:
	minikube -p $(MINIKUBE_PROFILE) addons enable ingress
	kubectl apply -f https://raw.githubusercontent.com/containous/traefik/master/examples/k8s/traefik-deployment.yaml

helm-status:
	helm status $(HELM_RELEASE_NAME)

helm-upgrade: helm-upgrade-dep helm-upgrade-install

helm-upgrade-dep:
	helm dep build $(CHART_LOCATION)

helm-upgrade-install:
	helm upgrade --install \
		--wait\
		--debug \
		$(HELM_RECREATE_PODS_ARG) \
		--namespace=$(NAMESPACE) \
		--timeout 300 \
		$(HELM_VALUES_ARG) \
		$(HELM_RELEASE_NAME) \
		$(CHART_LOCATION)

update-etc-host:
	./minikube-update-hosts.sh

test:
	make helm-upgrade HELM_VALUES_FILE=./test/minikube-values.yaml

test-and-update-etc-host: test update-etc-host

helm-lint:
	helm lint \
		$(CHART_LOCATION) \
		--namespace=$(NAMESPACE) \
		--debug \
		$(HELM_VALUES_ARG)

lint: helm-lint

helm-delete:
	helm delete --purge \
		$(HELM_RELEASE_NAME)

wait:
	sleep 60

minikube-full-test: minikube-restart wait helm-init helm-delete test

kubectl-get-services:
	kubectl get services --namespace $(NAMESPACE)

kubectl-list-pods:
	kubectl get po -a --namespace $(NAMESPACE)
