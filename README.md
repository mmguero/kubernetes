### Setup

1. Install [k3s](https://k3s.io/)
    * Using [k3sup](https://github.com/alexellis/k3sup)
        * `k3sup install --local --k3s-channel stable --k3s-extra-args="--data-dir=/media/extra/k3s --kubelet-arg=root-dir=/media/extra/kubelet"`
    * Manually
        * `curl -sfL https://get.k3s.io | sh -`
2. Get the kubeconfig file
    * `sudo cp /etc/rancher/k3s/k3s.yaml /home/user/kubeconfig`
    * `sudo chown user:user /home/user/kubeconfig`
3 . Remove Traefik (in favor of ingress-nginx)
    * `helm uninstall traefik -n kube-system`
    * `helm uninstall traefik-crd -n kube-system`
    * `kubectl get pods -n kube-system | grep traefik | awk '{print $1}' | xargs -r -I "XXX" kubectl delete pod "XXX" -n kube-system`
4. Install [ingress-nginx](https://github.com/kubernetes/ingress-nginx)
    * Using [`deploy_ingress_nginx.sh`](scripts/deploy_ingress_nginx.sh), a convenience script which lets you do TLS-passthrough and some other nice stuff
        * `./scripts/deploy_ingress_nginx.sh -v -k /home/user/kubeconfig -s`
    * Manually (however doing this you may need to enable TLS-passthrough manually if you want it)
        * `kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.0/deploy/static/provider/cloud/deploy.yaml`
5. Wait for the ingress to be ready
    * `kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s`
6. Install [metallb](https://metallb.io/) load-balancer and set up your IP pool
    * `kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml`
    * `kubectl apply -f metallb/metallb-ip-pool.yaml`
7. Start a demo deployment (e.g., [whoami](https://github.com/traefik/whoami))
    * `kubectl apply -f whoami/whoami.yaml`
    * `curl -kL https://whoami.k3sdemo.example.org`

### Debugging

* `kubectl get svc -n ingress-nginx`
* `kubectl get ingress whoami-ingress`
* `kubectl get ingress -A -o wide`
* `kubectl get pods -n ingress-nginx`
* `kubectl get pods -n metallb-system`
* `kubectl get endpoints whoami`
* `kubectl get pods -l app=whoami`
* `kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx`
* `kubectl logs -n metallb-system -l component=speaker`
* `kubectl logs whoami-7457f5bd7-j79tl`