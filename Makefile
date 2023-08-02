INCLUDE_DIR=make
NAME=porter-argo-demo
NAMESPACE=demo
#TODO (bdegeeter): support azure, aws, gcp and local (kind)
CLOUD=local
KIND_INGRESS_DIR=deploy/k8s-ingress-nginx/overlays/kind/default-ingress-secret
KIND_INGRESS_CRT=$(KIND_INGRESS_DIR)/kind-tls.crt
KIND_INGRESS_KEY=$(KIND_INGRESS_DIR)/kind-tls.key
KIND_INGRESS_DOMAIN=porter-argo.localtest.me

include $(INCLUDE_DIR)/Makefile.tools

$(KIND_INGRESS_CRT): $(KIND_INGRESS_KEY)
	openssl req -new -x509 -key $(KIND_INGRESS_KEY) -out $(KIND_INGRESS_CRT) -days 365 -subj "/CN=$(KIND_INGRESS_DOMAIN)"

$(KIND_INGRESS_KEY):
	openssl genpkey -algorithm RSA -out $(KIND_INGRESS_KEY) -pkeyopt rsa_keygen_bits:2048

.PHONY: deploy
deploy: | $(ARGO) $(if $(findstring $(CLOUD),local), $(KIND_INGRESS_CRT) kind-create-cluster)
	@echo "\ndeploy porter and demo to $(CLOUD)"
	# Double deploy to load CRDs if they are being loaded for the first time
	$(KCTL_CMD) get crd/installations.getporter.org || $(KCTL_CMD) apply -k deploy/$(CLOUD) || true 
	$(KCTL_CMD) apply -k deploy/$(CLOUD)
	$(KCTL_CMD) wait deployment -n $(NAMESPACE) porter-operator-controller-manager --for condition=Available=True --timeout=600s

.PHONY: test-installation
test-installation:
	$(KCTL_CMD) apply -n demo -f deploy/demo/test-installation.yaml

.PHONY: k9s
k9s: | $(K9S)
	$(K9S_CMD)

.PHONY: clean
clean: | clean-tools
