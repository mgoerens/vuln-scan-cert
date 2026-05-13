# Vulnerability scanner certification pipeline for RHACS

## Pre-requisites 

### Deploy OCP cluster

Requirements TBD

### Install OpenShift Pipelines operator (Tekton)

https://docs.redhat.com/en/documentation/red_hat_openshift_pipelines/1.21/html/installing_and_configuring/installing-pipelines

### Red Hat SSO Service Account

- Follow this link to create a Red Hat Service Account: https://console.redhat.com/iam/service-accounts/
- Save Client ID and Client Secret
```shell
$ export CLIENT_ID=<my-client-id>
$ export CLIENT_SECRET=<my-client-secret>
```
- Create Kubernetes Secret
```shell
$ envsubst < rh-openid-credentials/rh-openid-credentials.template.yaml | oc apply -f -
```

### Apply RHACS Tasks and Pipeline definitions

```shell
$ oc apply -f tasks/
$ oc apply -f pipeline/
```

### Increase the maximum Task result size using sidecar logs

Documentation: https://tekton.dev/docs/pipelines/additional-configs/#enabling-larger-results-using-sidecar-logs

```shell
$ oc apply -f enable-log-access-to-controller/rbac.yaml
$ oc patch cm feature-flags -n openshift-pipelines -p '{"data":{"results-from":"sidecar-logs"}}'
$ oc patch cm feature-flags -n openshift-pipelines -p '{"data":{"max-result-size":"8192"}}'
```

This is required due to the size of the `ROX_API_TOKEN`, exceeding the default 4096 bytes.

### Build Container images used in python steps

```shell
$ oc new-build --name python3-with-requests --binary --strategy docker
$ oc patch bc/python3-with-requests -p '{"spec":{"strategy":{"dockerStrategy":{"dockerfilePath":"Containerfile"}}}}'
$ oc start-build python3-with-requests --from-dir=./python-with-requests --follow
```

The image is now available in the internal registry `image-registry.openshift-image-registry.svc:5000/default/python3-with-requests:latest`.

It is used in steps that run Python code and require the `requests` module.

## Usage

Start a pipeline run either via CLI or via Manifest file

### `tkn` CLI

```
tkn pipeline start rhacs \
  -n default \
  --param image=alpine \
  -w name=bin,volumeClaimTemplateFile=./pipeline/pvc-template.yaml \
  --pipeline-timeout 1h \
  --showlog
```

### Apply PipelineRun YAML

This is an alternative to the `tkn` CLI.

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: rhacs-run
  namespace: default
spec:
  pipelineRef:
    name: rhacs
  params:
  - name: image
    value: alpine
  timeouts:
    pipeline: 1h0m0s
  workspaces:
    - name: bin
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 1Gi
          storageClassName: gp3-csi
          volumeMode: Filesystem
```

Apply and view logs:

```bash
oc apply -f run-rhacs-pr.yaml -n default
tkn pipelinerun logs -f rhacs-cli -n default
```
