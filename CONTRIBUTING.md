## Cutting a release

```sh
helm unittest chart/application
# Bump version in chart/application/Chart.yaml
helm package chart/application
# Use the right version of course
gh release create v0.0.1 ./epinio-application-traefiked-*.tgz
```
