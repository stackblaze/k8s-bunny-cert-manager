{{/*
Chart name
*/}}
{{- define "cert-manager-bunny.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified name
*/}}
{{- define "cert-manager-bunny.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Secret name for Bunny credentials — must match RBAC
*/}}
{{- define "cert-manager-bunny.secretName" -}}
bunny-credentials
{{- end }}

{{/*
ClusterIssuer name
*/}}
{{- define "cert-manager-bunny.issuerName" -}}
{{- printf "%s-letsencrypt" (include "cert-manager-bunny.fullname" .) }}
{{- end }}

{{/*
Certificate name
*/}}
{{- define "cert-manager-bunny.certName" -}}
{{- printf "%s-tls" (.Values.domain | replace "." "-") }}
{{- end }}

{{/*
Validate required values
*/}}
{{- define "cert-manager-bunny.validate" -}}
{{- if not .Values.bunny.apiKey -}}
{{- fail "bunny.apiKey is required" -}}
{{- end -}}
{{- if not .Values.domain -}}
{{- fail "domain is required" -}}
{{- end -}}
{{- if not .Values.acme.email -}}
{{- fail "acme.email is required" -}}
{{- end -}}
{{- end }}
