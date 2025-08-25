# Deploy [Step Certificates](https://github.com/smallstep/helm-charts/blob/master/step-certificates/README.md) (step-ca) with [Helm](https://github.com/smallstep/helm-charts)

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
3. Add the ACME provisioner to `values.yaml`
```bash
$ sed -i '/"type":"JWK"/a \ \ \ \ \ \ \ \ \ \ \ \ - {"type":"ACME","name":"acme"}' values.yaml
```
4. base64-encode password into `password.txt`
```bash
$ echo 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' | base64 > password.txt
```
5. Install Helm chart
```bash
$ helm upgrade --install \
    -f values.yaml \
    --set service.targetPort=443 \
    --set inject.secrets.ca_password=$(cat password.txt) \
    --set inject.secrets.provisioner_password=$(cat password.txt) \
    --create-namespace -n ca \
    step-ca smallstep/step-certificates
```
6. Install ingress
```bash
$ kubectl apply -f step-ca/step-ca-ingress.yaml
```
7. Test health
```bash
$ curl --insecure https://ca.k3sdemo.example.org/health
{"status":"ok"}
```
8. Install cert-manager and give it the root CA cert
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
9. Create certificate issuer
```bash
$ kubectl apply -f step-ca/step-ca-issuer.yaml
````
10. Patch ingress-nginx-admission
```bash
$ kubectl patch \
    validatingwebhookconfiguration \
    ingress-nginx-admission \
    --type='json' \
    -p='[{"op":"remove","path":"/webhooks/0"}]'
```
11. Annotate your service(s) (e.g., for [`whoami/whoami.yaml`](whoami/whoami.yaml), add or uncomment `annotations.cert-manager.io/cluster-issuer`  and the `spec.tls` section) and (re)deploy
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
