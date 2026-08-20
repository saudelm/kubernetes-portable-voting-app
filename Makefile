SHELL := /bin/bash

.PHONY: tools-check cluster-up build-local tf-init tf-apply local pods urls validate portability evidence \
	install-tools-ps tools-check-ps cluster-up-ps build-local-ps tf-init-ps tf-apply-ps pods-ps urls-ps validate-ps github-push-ps

tools-check:
	./scripts/tools-check.sh

cluster-up:
	./scripts/cluster-up.sh

build-local:
	./scripts/build-local.sh

tf-init:
	./scripts/tf-init.sh

tf-apply:
	./scripts/tf-apply.sh

local: cluster-up build-local tf-init tf-apply pods urls

pods:
	./scripts/pods.sh

urls:
	./scripts/urls.sh

validate:
	./scripts/validate.sh

portability:
	ruby scripts/compare-portability.rb

evidence:
	./scripts/collect-evidence.sh local

install-tools-ps:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-tools.ps1

tools-check-ps:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tools-check.ps1

cluster-up-ps:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/cluster-up.ps1

build-local-ps:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-local.ps1

tf-init-ps:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tf-init.ps1

tf-apply-ps:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tf-apply.ps1

pods-ps:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/pods.ps1

urls-ps:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/urls.ps1

validate-ps:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate.ps1

github-push-ps:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/github-push.ps1
