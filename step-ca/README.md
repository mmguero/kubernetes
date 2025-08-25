# Deploy [Step Certificates](https://github.com/smallstep/helm-charts/blob/master/step-certificates/README.md) (step-ca) TLS certificate authority with [Helm](https://github.com/smallstep/helm-charts) on Kubernetes

1. Add smallstep Helm repo
```bash
$ helm repo add smallstep https://smallstep.github.io/helm-charts/`
```
2. Initialize `values.yaml`
```bash
$ step ca init --helm \
    --deployment-type standalone \
    --name step-ca \
    --dns ca.k3sdemo.example.org \
    --dns step-ca.ca.svc.cluster.local \
    --address :443 \
    --provisioner primero > values.yaml
✔ Deployment Type: Standalone
Choose a password for your CA keys and first provisioner.
✔ [leave empty and we'll generate one]: 
✔ Password: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

Generating root certificate... done!
Generating intermediate certificate... done!
```
3. Generate SSH host and user CA keys (for SSH key provisioning)
```bash
$ step crypto keypair ssh_host_ca_key.pub ssh_host_ca_key
Please enter the password to encrypt the private key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
$ step crypto keypair ssh_user_ca_key.pub ssh_user_ca_key
Please enter the password to encrypt the private key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
$ tr -d '\n' < ssh_host_ca_key.pub | sponge ssh_host_ca_key.pub
$ tr -d '\n' < ssh_user_ca_key.pub | sponge ssh_user_ca_key.pub
```
4. Add the SSH keys to `values.yaml`
```bash
$ yq eval -i '
  .inject.certificates.ssh_host_ca = strload("ssh_host_ca_key.pub") |
  .inject.certificates.ssh_user_ca = strload("ssh_user_ca_key.pub") |
  .inject.secrets.ssh.host_ca_key = strload("ssh_host_ca_key") |
  .inject.secrets.ssh.user_ca_key = strload("ssh_user_ca_key")
' ./values.yaml
$ rm -f ./ssh_host_ca_key ./ssh_host_ca_key.pub ./ssh_user_ca_key ./ssh_user_ca_key.pub
```
5. Add the ACME provisioner to `values.yaml` and add enableSSHCA  claim to JWK provisioner
```bash
$ yq -i '.inject.config.files."ca.json".ssh.enabled = true' values.yaml
$ sed -i '/enableAdmin:/a \ \ \ \ \ \ \ \ \ \ ssh: {"hostKey": "/home/step/secrets/ssh_host_ca_key", "userKey": "/home/step/secrets/ssh_user_ca_key"}' values.yaml
$ sed -i 's/\("ssh":[[:space:]]*{}}\)/\1,"claims":{"enableSSHCA":true}/' values.yaml
$ sed -i '/"type":[[:space:]]*"JWK"/a \ \ \ \ \ \ \ \ \ \ \ \ - {"type":"ACME","name":"acme"}' values.yaml
```
6. base64-encode password into `password.txt`
```bash
$ echo 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' | base64 > ./password.txt
$ chmod 600 ./password.txt
```
7. Install Helm chart
```bash
$ helm upgrade --install \
    -f values.yaml \
    --set service.targetPort=443 \
    --set inject.secrets.ca_password=$(cat ./password.txt) \
    --set inject.secrets.provisioner_password=$(cat ./password.txt) \
    --create-namespace -n ca \
    step-ca smallstep/step-certificates
```
8. Install ingress for step-ca
```bash
$ kubectl apply -f step-ca/step-ca-ingress.yaml
```
9. Test health
```bash
$ curl --insecure https://ca.k3sdemo.example.org/health
{"status":"ok"}
```
10. Install cert-manager and give it the root CA cert
```bash
$ kubectl create namespace cert-manager
$ curl --insecure -o ./ca.pem https://ca.k3sdemo.example.org/roots.pem
$ kubectl -n cert-manager create configmap step-ca-root --from-file=ca.crt=ca.pem
$ kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml
$ ./step-ca/get-and-patch-cert-manager-for-step-ca.sh > ./cert-manager.yaml
$ kubectl apply -f ./cert-manager.yaml
$ kubectl get pods -n cert-manager
$ rm -f ./cert-manager.yaml ./ca.pem
```
11. Create certificate issuer
```bash
$ kubectl apply -f step-ca/step-ca-issuer.yaml
````
12. Patch ingress-nginx-admission
```bash
$ kubectl patch \
    validatingwebhookconfiguration \
    ingress-nginx-admission \
    --type='json' \
    -p='[{"op":"remove","path":"/webhooks/0"}]'
```
13. Annotate your service(s) (e.g., for [`whoami/whoami.yaml`](whoami/whoami.yaml), add or uncomment `annotations.cert-manager.io/cluster-issuer`  and the `spec.tls` section) and (re)deploy
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami-ingress
  annotations: {}
  annotations:
    cert-manager.io/cluster-issuer: step-ca-issuer
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - whoami.k3sdemo.example.org
      secretName: whoami-tls
  rules:
    - host: whoami.k3sdemo.example.org
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: whoami
                port:
                  number: 80
```
