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
      "secure.example.com": {
        "entryPoint":   "websecure",
        "tlsOptions": { "name": "my-tls-option", "namespace": "default" },
        "middlewares": [
          { "name": "ratelimit", "namespace": "traefik" }
        ]
      },
      "issued.example.com": {
        "entryPoint": "websecure",
        "tlsIssuer":  "my-cluster-issuer"
      }
    }
```

- Inner fields (`entryPoint`, `tlsIssuer`, `tlsOptions`, `middlewares`) are all
  optional; omitting one leaves it at its default for that domain.
- `middlewares` is an array of `{name, namespace}` objects. When the resolved
  `entryPoint` is `"websecure"`, the middleware `{"name":"crowdsec","namespace":"crowdsec"}`
  is automatically prepended unless already present.

### Defaults per domain

| Setting | External domain | `*.internal.foss.net.za` domain |
|---------|-----------------|----------------------------------|
| `entryPoint` | `"websecure"` | `"internalsecure"` |
| `tlsIssuer` | `"letsencrypt-production"` | `"step-ca"` |

TLS is enabled when the resolved `entryPoint` ends with `"secure"` or when
`tlsOptions` is explicitly set for the domain.

### cert-manager Certificate

`tlsIssuer` enables cert-manager certificate issuance for a domain. When set,
the chart generates a cert-manager `Certificate` (one per domain, deduplicated
across routes sharing that domain) and the `IngressRoute` references it via
`tls.secretName`.

Epinio only validates that the `traefik` setting exists and is a string; the
JSON structure is enforced at chart render time.

### Example: `epinio push`

The `traefik` setting is passed as a single JSON string via `-v`. The flag is
parsed as CSV (cobra `StringSlice`), so a value containing `"` must be
CSV-escaped: wrap the whole `name=value` field in double quotes and double
every inner `"`. With `jq -c` to compact the JSON, this looks like:

```bash
TRAEFIK=$(jq -c '.' <<'EOF'
{
  "secure.example.com": {
    "entryPoint": "websecure",
    "tlsIssuer": "letsencrypt-production"
  }
}
EOF
)
epinio push --name myapp --app-chart traefiked \
  -v "\"traefik=${TRAEFIK//\"/\"\"}\""
```

The `${TRAEFIK//\"/\"\"}` bash parameter expansion doubles every `"` in the
compacted JSON, and the `\"` at each end produces literal `"` characters that
wrap the field for the CSV parser. If you prefer, you can skip the variable and
write the escaped literal yourself:

```bash
epinio push --name myapp --app-chart traefiked \
  -v "\"traefik={""secure.example.com"":{""entryPoint"":""websecure"",""tlsIssuer"":""letsencrypt-production""}}\""
```

### Example: cert-managed TLS per domain

To have cert-manager issue the certificate for a domain instead of traefik's
`certResolver`, set `tlsIssuer` to a `ClusterIssuer` name. The chart generates
a `Certificate` and wires the `IngressRoute`'s `tls.secretName` to it, so the
two stay in sync:

```bash
TRAEFIK=$(jq -c '.' <<'EOF'
{
  "secure.example.com": {
    "entryPoint": "websecure"
  },
  "issued.example.com": {
    "entryPoint": "websecure",
    "tlsIssuer": "my-cluster-issuer"
  }
}
EOF
)
epinio push --name myapp --app-chart traefiked \
  -v "\"traefik=${TRAEFIK//\"/\"\"}\""
```

## Priority Class

`userConfig.priorityClassName` is a plain string. When specified (non-empty),
the deployment's `spec.template.spec.priorityClassName` is set to this value:

```yaml
userConfig:
  priorityClassName: high-priority
```
