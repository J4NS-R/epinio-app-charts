test:
  helm unittest chart/application

package:
  helm package chart/application

version := shell("yq '.version' < chart/application/Chart.yaml")
release: test package
  @echo "Releasing version {{version}}"
  gh release create "v{{version}}" "./epinio-application-traefiked-{{version}}.tgz"
