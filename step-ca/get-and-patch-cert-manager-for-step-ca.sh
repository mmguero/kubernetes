#!/usr/bin/env bash

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null 2>&1

curl -sSL -o ./cert-manager.yaml https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

if [[ -f ./cert-manager.yaml ]]; then
  yq --split-exp '"doc_" + $index' --no-doc ./cert-manager.yaml
  readarray -d '' DOC_FILES_SPLIT < <(printf '%s\0' doc_*.yml | sort -zV)

  for DOC_FILE in "${DOC_FILES_SPLIT[@]}"; do
    if [[ -s "${DOC_FILE}" ]]; then
        if (( $(yq 'select(.kind == "Deployment" and .metadata.name == "cert-manager")' "${DOC_FILE}" | wc -l) > 0 )); then
            yq eval -i '
              select(.kind == "Deployment" and .metadata.name == "cert-manager") |
              .spec.template.spec.volumes |= (. // []) + [{"name":"step-ca-root","configMap":{"name":"step-ca-root"}}] |
              .spec.template.spec.containers[] |= (
                select(.name == "cert-manager-controller") |
                .volumeMounts |= (. // []) + [{"name":"step-ca-root","mountPath":"/usr/local/share/ca-certificates/step-root-ca.crt","subPath":"ca.crt"}] |
                .env |= (. // []) + [{"name":"SSL_CERT_FILE","value":"/usr/local/share/ca-certificates/step-root-ca.crt"}]
              )
            ' "${DOC_FILE}"
        fi
        echo "---"
        cat "${DOC_FILE}"
    fi
  done
fi

popd >/dev/null 2>&1
rm -rf "${TEMP_DIR}"