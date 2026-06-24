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
      }
    }
```

- Top-level keys are domains, plus a reserved `"*"` fallback for any route
  whose domain is not explicitly listed.
- Inner fields (`entryPoint`, `certResolver`, `tlsOptions`) are all optional;
  omitting one leaves it unset for that domain.
- `tlsOptions` is resolved as a whole object (`name` and `namespace` both
  optional inside it).
- Resolution per route, per field:
  `config[domain].field` -> `config["*"].field` -> unset.

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
