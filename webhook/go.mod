module github.com/stackblaze/k8s-bunny-cert-manager/webhook

go 1.23

require (
	github.com/cert-manager/cert-manager v1.16.5
	github.com/simplesurance/bunny-go v0.0.0-20230727134852-2e9f020229f4
	k8s.io/api v0.31.1
	k8s.io/apiextensions-apiserver v0.31.1
	k8s.io/apimachinery v0.31.1
	k8s.io/client-go v0.31.1
)
