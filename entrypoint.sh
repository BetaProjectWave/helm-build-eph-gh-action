#!/bin/bash
echo "ARTIFACT_NAME: $ARTIFACT_NAME"
echo "REPO_URL: $REPO_URL"
echo "GITHUB_SHA: $GITHUB_SHA"
echo "CIRCLE_BUILD_NUM: $CIRCLE_BUILD_NUM"

EPH_DOCKER_TAG=$(echo e-$( date +%s)-$GITHUB_SHA)
EPH_HELM_APP_VERSION=$(echo v0.0.0-$EPH_DOCKER_TAG)
EPH_HELM_CHART_VERSION=$(echo v0.0.0-e-$( date +%s)-$GITHUB_RUN_NUMBER)
echo Using EPH_DOCKER_TAG $EPH_DOCKER_TAG
echo Using EPH_HELM_APP_VERSION $EPH_HELM_APP_VERSION
echo Using EPH_HELM_CHART_VERSION $EPH_HELM_CHART_VERSION

echo "::set-output name=eph_docker_tag::$EPH_DOCKER_TAG"
echo "::set-output name=eph_helm_app_version::$EPH_HELM_APP_VERSION"
echo "::set-output name=eph_helm_chart_version::$EPH_HELM_CHART_VERSION"

PACKAGE=`yq e .template.package helm.yaml`
helm repo add remote-repo $REPO_URL --username $REPO_USER --password $REPO_PASS && helm repo update
helm fetch remote-repo/${PACKAGE} --version `yq e '.template.version //0'  helm.yaml`

find . -name ${PACKAGE}-*.tgz -maxdepth 1 -exec tar -xvf {} \;
mv ${PACKAGE} ${ARTIFACT_NAME}
cd ${ARTIFACT_NAME}

sed -i.bak "s#name: ${PACKAGE}#name: ${ARTIFACT_NAME}#"  Chart.yaml
yq eval-all -i 'select(filename == "values.yaml") * select(filename == "../helm.yaml")' values.yaml ../helm.yaml
yq eval -i '.image.tag = "'${EPH_DOCKER_TAG}'"' values.yaml
helm package --app-version $EPH_HELM_APP_VERSION --version $EPH_HELM_CHART_VERSION .
curl -u $REPO_USER:$REPO_PASS -T ${ARTIFACT_NAME}-${EPH_HELM_CHART_VERSION}.tgz "$REPO_URL/${ARTIFACT_NAME}-${EPH_HELM_CHART_VERSION}.tgz"

echo "::set-output name=eph_uploaded_file::${REPO_URL}/${ARTIFACT_NAME}-${EPH_HELM_CHART_VERSION}.tgz"
