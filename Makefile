export KUBECONFIG ?= $(HOME)/.kube/kind-interview.yaml

CLUSTER ?= interview
ENV_DIR := infra/environments/local
IMAGE ?= skizay/posts-api
TAG ?= dev
REGISTRY ?= public
# Load-test users; sized for an 8 GB host. Raise on bigger machines: VUS=20 make chaos
export VUS ?= 10

.PHONY: setup up down infra build kind-load deploy test load chaos lint grafana hosts drain

setup:
	mise install
	pre-commit install

up: infra build kind-load deploy

infra:
	cd $(ENV_DIR) && terragrunt stack run apply --non-interactive

down:
	-cd $(ENV_DIR) && terragrunt stack run destroy --non-interactive
	-kind delete cluster --name $(CLUSTER)

build:
	docker build -t $(IMAGE):$(TAG) app

kind-load:
	kind load docker-image $(IMAGE):$(TAG) --name $(CLUSTER)

deploy:
	scripts/helm/deploy-app.sh --registry $(REGISTRY) --tag $(TAG)

test:
	k6 run tests/load/smoke.js

load:
	k6 run tests/load/load.js

chaos:
	tests/chaos/zone-outage.sh
	tests/chaos/mysql-primary-kill.sh
	tests/chaos/rolling-upgrade.sh
	tests/chaos/pod-kill.sh

lint:
	pre-commit run --all-files

grafana:
	scripts/cluster/grafana-info.sh

hosts:
	scripts/cluster/add-hosts.sh

drain:
	scripts/cluster/drain-node.sh --node $(NODE)
