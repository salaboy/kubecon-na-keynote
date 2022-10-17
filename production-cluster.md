# Creating a Production Clusters and installing tools


First let's create a Kubernetes Cluster with only the tools that will be needed in production tools using [KinD](https://kind.sigs.k8s.io/):

```
cat <<EOF | kind create cluster --name production --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 31080 # expose port 31380 of the node to port 80 on the host, later to be use by kourier or contour ingress
    listenAddress: 127.0.0.1
    hostPort: 81
networking:
  apiServerAddress: "<LOCAL IP address>"
  apiServerPort: 8443    
EOF
```

Let's create a `production` namespace to deploy our applications
```
kubectl create namespace production
```

After creating the cluster you can switch between the platform and the production cluster using `kubectl`:

To connect to the production cluster: 
```
kubectl config use-context kind-production
```

To connect to the platform cluster: 
```
kubectl config use-context kind-platform
```

## Installing Knative Serving

Let's install Knative Serving in the cluster: 

[Check this link for full instructions from the official docs](https://knative.dev/docs/install/yaml-install/serving/install-serving-with-yaml/#prerequisites)

```
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.7.2/serving-crds.yaml

```

```
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.7.2/serving-core.yaml

```

```
kubectl apply -f https://github.com/knative/net-kourier/releases/download/knative-v1.7.0/kourier.yaml

```

```
kubectl patch configmap/config-network \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"ingress-class":"kourier.ingress.networking.knative.dev"}}'

```


```
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.7.2/serving-default-domain.yaml

```

## Only for Knative on KinD
For Knative Magic DNS to work in KinD you need to patch the following ConfigMap:

```
kubectl patch configmap -n knative-serving config-domain -p "{\"data\": {\"127.0.0.1.sslip.io\": \"\"}}"
```

and if you installed the `kourier` networking layer you need to create an ingress:

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: kourier-ingress
  namespace: kourier-system
  labels:
    networking.knative.dev/ingress-provider: kourier
spec:
  type: NodePort
  selector:
    app: 3scale-kourier-gateway
  ports:
    - name: http2
      nodePort: 31080
      port: 80
      targetPort: 8080
EOF
```

## Configure auto-TLS for production

```
kubectl apply -f https://github.com/knative/net-http01/releases/download/knative-v1.7.0/release.yaml

```

```
kubectl patch configmap/config-network \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"certificate-class":"net-http01.certificate.networking.knative.dev"}}'

```

```
kubectl patch configmap/config-network \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"auto-tls":"Enabled"}}'

```

## Register Production cluster to Platform ArgoCD installation

**Notice**: you need to add your local IP address so ArgoCD can connect to the production cluster API server. You can find yours by using ifconfig/ipconfig. Look for IP ranges in `192.168.x.x`, `172.16.x.x` or `10.x.x.x`. 

Now you need to switch to the platform cluster to register the production cluster so ArgoCD can deploy applications to it.

```
kubectl config use-context kind-platform
```

Get the ArgoCD admin password to connect using the `argocd` CLI. 

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

```
argocd cluster add kind-production --name production
```

