{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "epinio-application.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "epinio-application.labels" -}}
app.kubernetes.io/managed-by: epinio
app.kubernetes.io/part-of: {{ .Release.Namespace | quote }}
helm.sh/chart: {{ include "epinio-application.chart" . }}
{{ include "epinio-application.selectorLabels" . }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "epinio-application.annotations" -}}
epinio.io/created-by: {{ .Values.epinio.username | quote }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "epinio-application.selectorLabels" -}}
app.kubernetes.io/name: {{ .Values.epinio.appName | quote }}
app.kubernetes.io/component: application
{{- end }}

{{/*
Removes characters that are invalid for kubernetes resource names from the
given string
*/}}
{{- define "epinio-name-sanitize" -}}
{{ regexReplaceAll "[^-a-z0-9]*" . "" }}
{{- end }}

{{/*
Resource name sanitization and truncation.
- Always suffix the sha1sum (40 characters long)
- Always add an "r" prefix to make sure we don't have leading digits
- The rest of the characters up to 63 are the original string with invalid
character removed.
*/}}
{{- define "epinio-truncate" -}}
{{ print "r" (trunc 21 (include "epinio-name-sanitize" .)) "-" (sha1sum .) }}
{{- end }}

{{/*
Application listening port
*/}}
{{- define "epinio-app-listening-port" -}}
{{ default 8080 (default (dict "appListeningPort" "8080") .Values.userConfig).appListeningPort }}
{{- end }}

{{/*
Application service name (truncated appName)
*/}}
{{- define "epinio-app-service-name" -}}
{{ include "epinio-truncate" .Values.epinio.appName }}
{{- end }}

{{/*
Parse userConfig.traefik into a config map.

The value is a JSON document mapping domain -> traefik configuration. The
reserved "*" key and the "certResolver" field are no longer supported and will
cause a render failure. Missing/empty -> empty map. Malformed JSON or a
non-object top-level value -> fail with a clear message naming the setting.

Returns the parsed map (round-tripped through toJson so callers can safely
fromJson it back into a map, even when it is the empty {}).
*/}}
{{- define "epinio-traefik-config" -}}
{{- $raw := .Values.userConfig.traefik | default "" -}}
{{- if eq (trim $raw) "" -}}
{}
{{- else -}}
{{- $parsed := $raw | fromJson -}}
{{- if hasKey $parsed "Error" -}}
{{- fail (printf "userConfig.traefik is not valid JSON: %s" $parsed.Error) -}}
{{- end -}}
{{- if hasKey $parsed "*" -}}
{{- fail "userConfig.traefik: the \"*\" wildcard key is no longer supported; specify per-domain settings explicitly" -}}
{{- end -}}
{{- range $domain, $settings := $parsed -}}
{{- if hasKey $settings "certResolver" -}}
{{- fail (printf "userConfig.traefik: \"certResolver\" is no longer supported for domain %s; use tlsIssuer instead" $domain) -}}
{{- end -}}
{{- end -}}
{{- $parsed | toJson -}}
{{- end -}}
{{- end }}

{{/*
Resolve the entryPoint for a route.

Arguments: (config, domain)
If config[domain].entryPoint is set, use it.
Otherwise, if the domain ends with ".internal.foss.net.za" use "internalsecure".
Otherwise, default to "websecure".

Returns the resolved entryPoint string.
*/}}
{{- define "epinio-route-entrypoint" -}}
{{- $cfg := index . 0 -}}
{{- $domain := index . 1 -}}
{{- $ep := "" -}}
{{- $dom := index $cfg $domain -}}
{{- if $dom -}}{{- if hasKey $dom "entryPoint" -}}{{- $ep = index $dom "entryPoint" -}}{{- end -}}{{- end -}}
{{- if eq $ep "" -}}
{{- if regexMatch "\\.internal\\.foss\\.net\\.za$" $domain -}}
{{- $ep = "internalsecure" -}}
{{- else -}}
{{- $ep = "websecure" -}}
{{- end -}}
{{- end -}}
{{- $ep -}}
{{- end }}

{{/*
Resolve whether a route should have a TLS block.

Arguments: (entryPoint, tlsOptionsEmpty)
Returns "true" when the entryPoint ends with "secure" or when tlsOptions
is non-empty (i.e. the user explicitly set tlsOptions for this domain).
Otherwise returns "" (falsy).
*/}}
{{- define "epinio-route-has-tls" -}}
{{- $ep := index . 0 -}}
{{- $tlsOptsEmpty := index . 1 -}}
{{- $result := "" -}}
{{- if regexMatch "secure$" $ep -}}{{- $result = "true" -}}{{- end -}}
{{- if not $tlsOptsEmpty -}}{{- $result = "true" -}}{{- end -}}
{{- $result -}}
{{- end }}

{{/*
Resolve the tlsIssuer for a route.

Arguments: (config, domain)
If config[domain].tlsIssuer is set, use it.
Otherwise, if the domain ends with ".internal.foss.net.za" use "step-ca".
Otherwise, default to "letsencrypt-production".

Returns the resolved tlsIssuer string.
*/}}
{{- define "epinio-route-tls-issuer" -}}
{{- $cfg := index . 0 -}}
{{- $domain := index . 1 -}}
{{- $ti := "" -}}
{{- $dom := index $cfg $domain -}}
{{- if $dom -}}{{- if hasKey $dom "tlsIssuer" -}}{{- $ti = index $dom "tlsIssuer" -}}{{- end -}}{{- end -}}
{{- if eq $ti "" -}}
{{- if regexMatch "\\.internal\\.foss\\.net\\.za$" $domain -}}
{{- $ti = "step-ca" -}}
{{- else -}}
{{- $ti = "letsencrypt-production" -}}
{{- end -}}
{{- end -}}
{{- $ti -}}
{{- end }}

{{/*
Resolve the tlsOptions object for a route.

Arguments: (config, domain)
Only looks at config[domain].tlsOptions (no wildcard fallback).

Returns a JSON object {"name":..., "namespace":...} with only the fields that
are present and non-empty in the resolved tlsOptions. Returns "{}" when no
tlsOptions applies, which callers detect via `empty`.
*/}}
{{- define "epinio-route-traefik-tls-options" -}}
{{- $cfg := index . 0 -}}
{{- $domain := index . 1 -}}
{{- $t := dict -}}
{{- $dom := index $cfg $domain -}}
{{- if $dom -}}{{- if hasKey $dom "tlsOptions" -}}{{- $t = index $dom "tlsOptions" -}}{{- end -}}{{- end -}}
{{- $out := dict -}}
{{- if not (empty $t) -}}
{{- $name := index $t "name" | default "" -}}
{{- $ns := index $t "namespace" | default "" -}}
{{- if ne $name "" -}}{{- $_ := set $out "name" $name -}}{{- end -}}
{{- if ne $ns "" -}}{{- $_ := set $out "namespace" $ns -}}{{- end -}}
{{- end -}}
{{- $out | toJson -}}
{{- end }}

{{/*
Resolve the cert-manager Certificate / IngressRoute TLS secret name for a
domain.

Arguments: (appName, domain)
Returns the sanitized and truncated form of "<appName>-<domain>-tls" so the
same secret name is referenced by both the IngressRoute (tls.secretName) and
the cert-manager Certificate (metadata.name, spec.secretName).
*/}}
{{- define "epinio-tls-secret-name" -}}
{{- $appName := index . 0 -}}
{{- $domain := index . 1 -}}
{{ include "epinio-truncate" (print $appName "-" $domain "-tls") }}
{{- end }}

{{/*
Parse userConfig.serviceAccount into a config map.

The value is a JSON document with fields like "enabled". Missing/empty ->
empty map. Malformed JSON or a non-object top-level value -> fail with a clear
message naming the setting.

Returns the parsed map (round-tripped through toJson so callers can safely
fromJson it back into a map, even when it is the empty {}).
*/}}
{{- define "epinio-serviceaccount-config" -}}
{{- $raw := .Values.userConfig.serviceAccount | default "" -}}
{{- if eq (trim $raw) "" -}}
{}
{{- else -}}
{{- $parsed := $raw | fromJson -}}
{{- if hasKey $parsed "Error" -}}
{{- fail (printf "userConfig.serviceAccount is not valid JSON: %s" $parsed.Error) -}}
{{- end -}}
{{- $parsed | toJson -}}
{{- end -}}
{{- end }}

{{/*
Resolve whether the service account is enabled.

Returns "true" when userConfig.serviceAccount.enabled is true, "" otherwise.
*/}}
{{- define "epinio-serviceaccount-enabled" -}}
{{- $cfg := include "epinio-serviceaccount-config" . | fromJson -}}
{{- if hasKey $cfg "enabled" -}}
{{- if $cfg.enabled -}}true{{- end -}}
{{- end -}}
{{- end }}