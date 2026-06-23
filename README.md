# Epinio Custom AppCharts

Forked from [epinio/helm-charts](https://github.com/epinio/helm-charts)

## Features

Routing is provided by a traefik `IngressRoute` (instead of a standard
`Ingress`). The following optional values control the traefik configuration and
live under `userConfig.traefik` (outside the epinio server API):

```yaml
userConfig:
  traefik_entrypoint: websecure
  traefik_tls_certResolver: letsencrypt
  traefik_tls_options_name: my-tls-option
  traefik_tls_options_namespace: default
```

- `traefik_entrypoint` — traefik entrypoint name to listen on.
- `traefik_tls_certResolver` — traefik certificate resolver to use.
- `traefik_tls_options_name` / `traefik_tls_options_namespace` — reference a `TLSOption`.
