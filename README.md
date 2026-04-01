### Setup
1. Install [k3s](https://k3s.io/), using [k3sup](https://github.com/alexellis/k3sup)
    * `k3sup install --local --k3s-channel stable --k3s-extra-args="--disable traefik --data-dir=/media/extra/k3s --kubelet-arg=root-dir=/media/extra/kubelet"`
2. Get the kubeconfig file
    * `sudo cp /etc/rancher/k3s/k3s.yaml /home/user/kubeconfig`
    * `sudo chown user:user /home/user/kubeconfig`
3. Install [MetalLB](https://metallb.io/) load-balancer and set up your IP pool
    * `kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml`
    * `kubectl apply -f metallb/metallb-ip-pool.yaml`
4. Install [Traefik](https://traefik.io/traefik/) via Helm
    * Add the Helm repo
        * `helm repo add traefik https://traefik.github.io/charts`
        * `helm repo update`
    * Install Traefik, using a custom [`traefik-values.yaml`](./traefik/traefik-values.yaml):
        * `helm upgrade --install traefik traefik/traefik --namespace traefik --create-namespace -f traefik-values.yaml`
5. Wait for Traefik to be ready
    * `kubectl rollout status deployment/traefik -n traefik --timeout=120s`
6. Confirm the load balancer IP was assigned
    * `kubectl get svc -n traefik`
7. Start a demo deployment (e.g. [whoami](https://github.com/traefik/whoami))
    * `kubectl apply -f whoami/whoami.yaml`
    * Make sure the Ingress uses:
        * `ingressClassName: traefik`
    * Test it
        * `curl -kL https://whoami.example.org`


### Debugging

* `kubectl get svc -n traefik`
* `kubectl get ingress whoami-ingress`
* `kubectl get ingress -A -o wide`
* `kubectl get ingressclass`
* `kubectl get pods -n traefik`
* `kubectl get pods -n metallb-system`
* `kubectl get endpoints whoami`
* `kubectl get pods -l app=whoami`
* `kubectl logs -n traefik deploy/traefik`
* `kubectl logs -n metallb-system -l component=speaker`
* `kubectl logs whoami-xxxxxxxxx-xxxxx`
* `kubectl get svc -A | grep LoadBalancer`
* `kubectl describe ingress whoami-ingress`
* `kubectl logs -n traefik deploy/traefik --tail=100`