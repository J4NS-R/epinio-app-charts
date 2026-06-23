# Epinio Custom AppCharts

Forked from [epinio/helm-charts](https://github.com/epinio/helm-charts)

## Features

Routing is provided by a traefik `IngressRoute` (instead of a standard
`Ingress`). The following optional values control the traefik configuration and
live under `userConfig.traefik` (outside the epinio server API):

```yaml
userConfig:
  traefik:
    entrypoint: websecure
    tls:
      certResolver: letsencrypt
      options:
        name: my-tls-option
        namespace: default
```

- `entrypoint` — traefik entrypoint name to listen on.
- `tls.certResolver` — traefik certificate resolver to use.
- `tls.options.name` / `tls.options.namespace` — reference a `TLSOption`.
