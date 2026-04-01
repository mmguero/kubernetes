# Deploy [Step Certificates](https://github.com/smallstep/helm-charts/blob/master/step-certificates/README.md) (step-ca) TLS certificate authority with [Helm](https://github.com/smallstep/helm-charts) on Kubernetes

1. Add smallstep Helm repo

```bash
helm repo add smallstep https://smallstep.github.io/helm-charts/
helm repo update
```

2. Initialize `values.yaml`

```bash
step ca init --helm \
    --deployment-type standalone \
    --name step-ca \
    --dns ca.example.org \
    --dns step-ca.ca.svc.cluster.local \
    --address :443 \
    --provisioner primero \
    --ssh > values.yaml
```

3. Add the ACME provisioner and set `ca.ssh.enabled=true` in `values.yaml`

```bash
sed -i '/"type":[[:space:]]*"JWK"/a \ \ \ \ \ \ \ \ \ \ \ \ - {"type":"ACME","name":"acme"}' values.yaml
sed -i '/userKey:[[:space:]]*\/home\/step\/secrets\/ssh_user_ca_key/a \ \ \ \ \ \ \ \ \ \ enabled: true' values.yaml
```

* If you want to [enable OIDC](https://github.com/mmguero/docker/tree/master/step-ca#oidcoauth), edit `values.yaml` and add an OIDC provisioner, e.g.:
  * `- {"type":"OIDC","name":"google","clientID":"123456789009-casdfa97asdfcasdf8jklj89090fasd1.apps.googleusercontent.com","clientSecret":"asdfFACSDsadf304JSDAcsl4","configurationEndpoint":"https://accounts.google.com/.well-known/openid-configuration","admins":["user@gmail.com"],"domains":["gmail.com"],"claims":{"enableSSHCA":true}}`


4. Base64-encode password into `password.txt`

```bash
echo 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' | base64 > ./password.txt
chmod 600 ./password.txt
```

5. Install Helm chart

```bash
helm upgrade --install \
    -f values.yaml \
    --set service.targetPort=443 \
    --set inject.secrets.ca_password=$(cat ./password.txt) \
    --set inject.secrets.provisioner_password=$(cat ./password.txt) \
    --create-namespace -n ca \
    step-ca smallstep/step-certificates
```

6. Create a Traefik `ServersTransport` for the Step CA backend

Because Step CA serves HTTPS on the backend service, Traefik needs a transport that skips backend certificate verification. Apply [`step-ca-transport.yaml`](./step-ca-transport.yaml):

```bash
kubectl apply -f step-ca/step-ca-transport.yaml
```

7. Expose Step CA through Traefik with an `IngressRoute`

Use a Traefik `IngressRoute` instead of a standard Kubernetes `Ingress`. Apply [`step-ca-ingress.yaml`](./step-ca-ingress.yaml):

```bash
kubectl apply -f step-ca/step-ca-ingress.yaml
```

8. Test health / ACME endpoint

```bash
curl --insecure https://ca.example.org/health
curl --insecure https://ca.example.org/acme/acme/directory
```

9. Install cert-manager and give it the root CA cert

```bash
kubectl create namespace cert-manager
curl --insecure -o ./ca.pem https://ca.example.org/roots.pem
kubectl -n cert-manager create configmap step-ca-root --from-file=ca.crt=ca.pem
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml
./step-ca/get-and-patch-cert-manager-for-step-ca.sh > ./cert-manager.yaml
kubectl apply -f ./cert-manager.yaml
kubectl get pods -n cert-manager
rm -f ./cert-manager.yaml ./ca.pem
```

10. Create certificate issuer

Make sure the ACME solver uses Traefik by applying [`step-ca-issuer.yaml`](./step-ca-issuer.yaml).

```bash
kubectl apply -f step-ca/step-ca-issuer.yaml
```

11. Annotate your service(s) and use `ingressClassName: traefik`, e.g.:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami-ingress
  annotations:
    cert-manager.io/cluster-issuer: step-ca-issuer
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - whoami.example.org
      secretName: whoami-tls
  rules:
    - host: whoami.example.org
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

12. See [bootstrapping clients](https://github.com/mmguero/docker/tree/master/step-ca#bootstrapping-clients) for notes on client use with `step`
