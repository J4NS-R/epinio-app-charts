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

The value is a JSON document mapping domain -> traefik configuration, with a
reserved "*" key acting as the fallback for any route whose domain is not
explicitly listed. Missing/empty -> empty map. Malformed JSON or a non-object
top-level value -> fail with a clear message naming the setting.

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
{{- $parsed | toJson -}}
{{- end -}}
{{- end }}

{{/*
Resolve a scalar traefik option for a route.

Arguments: (config, domain, field)
Resolution precedence: config[domain].field -> config["*"].field -> "" (unset)

Returns the resolved string value, or "" when unset. Callers should use
`with`/`if not (empty ...)` to omit the corresponding rendered field.
*/}}
{{- define "epinio-route-traefik-option" -}}
{{- $cfg := index . 0 -}}
{{- $domain := index . 1 -}}
{{- $field := index . 2 -}}
{{- $val := "" -}}
{{- $dom := index $cfg $domain -}}
{{- if $dom -}}{{- $val = index $dom $field | default "" -}}{{- end -}}
{{- if eq $val "" -}}
{{- $star := index $cfg "*" -}}
{{- if $star -}}{{- $val = index $star $field | default "" -}}{{- end -}}
{{- end -}}
{{- $val -}}
{{- end }}

{{/*
Resolve the tlsOptions object for a route.

Arguments: (config, domain)
Resolution precedence: config[domain].tlsOptions -> config["*"].tlsOptions -> unset

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
{{- if empty $t -}}
{{- $star := index $cfg "*" -}}
{{- if $star -}}{{- if hasKey $star "tlsOptions" -}}{{- $t = index $star "tlsOptions" -}}{{- end -}}{{- end -}}
{{- end -}}
{{- $out := dict -}}
{{- if not (empty $t) -}}
{{- $name := index $t "name" | default "" -}}
{{- $ns := index $t "namespace" | default "" -}}
{{- if ne $name "" -}}{{- $_ := set $out "name" $name -}}{{- end -}}
{{- if ne $ns "" -}}{{- $_ := set $out "namespace" $ns -}}{{- end -}}
{{- end -}}
{{- $out | toJson -}}
{{- end }}
