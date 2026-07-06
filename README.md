# Epinio Custom AppCharts

Forked from [epinio/helm-charts](https://github.com/epinio/helm-charts)

## Features

Routing is provided by a traefik `IngressRoute` (instead of a standard
`Ingress`). Traefik options are configurable per domain via a single composite
`userConfig.traefik` setting (outside the epinio server API) whose value is a
JSON document:

```yaml
userConfig:
  traefik: |
    {
      "*": {
        "entryPoint": "websecure"
      },
      "secure.example.com": {
        "entryPoint":   "websecure",
        "certResolver": "letsencrypt",
        "tlsOptions": { "name": "my-tls-option", "namespace": "default" }
      },
      "issued.example.com": {
        "entryPoint": "websecure",
        "tlsIssuer":  "my-cluster-issuer"
      }
    }
```

- Top-level keys are domains, plus a reserved `"*"` fallback for any route
  whose domain is not explicitly listed.
- Inner fields (`entryPoint`, `certResolver`, `tlsOptions`, `tlsIssuer`) are
  all optional; omitting one leaves it unset for that domain.
- `tlsOptions` is resolved as a whole object (`name` and `namespace` both
  optional inside it).
- Resolution per route, per field:
  `config[domain].field` -> `config["*"].field` -> unset.

`tlsIssuer` enables cert-manager certificate issuance for a domain. When set,
the chart generates a cert-manager `Certificate` (one per domain, deduplicated
across routes sharing that domain) and the `IngressRoute` references it via
`tls.secretName`. It is mutually exclusive with `certResolver` for the same
  domain: setting both fails the render with a clear message.

Epinio only validates that the `traefik` setting exists and is a string; the
JSON structure is enforced at chart render time (a malformed value fails the
render with a clear message).

### Example: `epinio push`

The `traefik` setting is passed as a single JSON string via `-v`. The flag is
parsed as CSV (cobra `StringSlice`), so a value containing `"` must be
CSV-escaped: wrap the whole `name=value` field in double quotes and double
every inner `"`. With `jq -c` to compact the JSON, this looks like:

```bash
TRAEFIK=$(jq -c '.' <<'EOF'
{
  "*": {
    "entryPoint": "internalsecure",
    "certResolver": "step-ca"
  }
}
EOF
)
epinio push --name nederkaans --app-chart traefiked \
  -v "\"traefik=${TRAEFIK//\"/\"\"}\""
```

The `${TRAEFIK//\"/\"\"}` bash parameter expansion doubles every `"` in the
compacted JSON, and the `\"` at each end produces literal `"` characters that
wrap the field for the CSV parser. If you prefer, you can skip the variable and
write the escaped literal yourself:

```bash
epinio push --name nederkaans --app-chart traefiked \
  -v "\"traefik={""*"":{""entryPoint"":""internalsecure"",""certResolver"":""step-ca""}}\""
```

### Example: cert-managed TLS per domain

To have cert-manager issue the certificate for a domain instead of traefik's
`certResolver`, set `tlsIssuer` to a `ClusterIssuer` name. The chart generates
a `Certificate` and wires the `IngressRoute`'s `tls.secretName` to it, so the
two stay in sync:

```bash
TRAEFIK=$(jq -c '.' <<'EOF'
{
  "*": {
    "entryPoint": "internalsecure"
  },
  "issued.example.com": {
    "entryPoint": "internalsecure",
    "tlsIssuer": "my-cluster-issuer"
  }
}
EOF
)
epinio push --name nederkaans --app-chart traefiked \
  -v "\"traefik=${TRAEFIK//\"/\"\"}\""
```

The `epinio.tlsIssuer` field is deprecated and ignored; use the per-domain
`tlsIssuer` in `userConfig.traefik` instead.

## Service Account

`userConfig.serviceAccount` is a JSON string that controls whether the
deployment uses a dedicated service account:

```yaml
userConfig:
  serviceAccount: |
    {
      "enabled": true
    }
```

- `enabled` (boolean, default `false`): when `true`, the chart creates a
  `ServiceAccount` resource and sets the deployment's `serviceAccountName` to
  it, with `automountServiceAccountToken: true`. When `false` (the default),
  no `ServiceAccount` is created, no `serviceAccountName` is set on the pod,
  and `automountServiceAccountToken` is set to `false`.

## Priority Class

`userConfig.priorityClassName` is a plain string. When specified (non-empty),
the deployment's `spec.template.spec.priorityClassName` is set to this value:

```yaml
userConfig:
  priorityClassName: high-priority
```
