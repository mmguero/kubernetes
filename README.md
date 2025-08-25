### Setup

1. install k3s
    * `curl -sfL https://get.k3s.io | sh -`
    * *or, with [k3sup](https://github.com/alexellis/k3sup)*
    * `k3sup install --local --k3s-channel stable --k3s-extra-args="--data-dir=/media/extra/k3s --kubelet-arg=root-dir=/media/extra/kubelet"`
3. `sudo cp /etc/rancher/k3s/k3s.yaml /home/user/kubeconfig`
4. `sudo chown user:user /home/user/kubeconfig`
4. uninstall traefik
    * `helm uninstall traefik -n kube-system`
    * `helm uninstall traefik-crd -n kube-system`
    * `kubectl get pods -n kube-system | grep traefik | awk '{print $1}' | xargs -r -I "XXX" kubectl delete pod "XXX" -n kube-system`
5. install ingress-nginx
    * `kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.0/deploy/static/provider/cloud/deploy.yaml`
    * *or*
    * [`deploy_ingress_nginx.sh -v -k $KUBECONFIG -s`](https://github.com/mmguero-dev/Malcolm/blob/main/kubernetes/vagrant/deploy_ingress_nginx.sh)
6. `kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s`
7. `kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml`
8. `kubectl apply -f matallb/metallb-ip-pool.yaml`
9. `kubectl apply -f whoami/whoami.yaml`
10. `curl -kL https://whoami.k3sdemo.example.org`

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