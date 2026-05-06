.PHONY: install-tools tools-check cluster-up build-local tf-init tf-apply pods urls validate github-push

install-tools:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-tools.ps1

tools-check:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tools-check.ps1

cluster-up:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/cluster-up.ps1

build-local:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-local.ps1

tf-init:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tf-init.ps1

tf-apply:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tf-apply.ps1

pods:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/pods.ps1

urls:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/urls.ps1

validate:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate.ps1

github-push:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/github-push.ps1
