# Creating a Platform Clusters and installing tools

First let's create a Kubernetes Cluster host the platform-wide tools using [KinD](https://kind.sigs.k8s.io/):

```
cat <<EOF | kind create cluster --name platform --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 31080 # expose port 31380 of the node to port 80 on the host, later to be use by kourier or contour ingress
    listenAddress: 127.0.0.1
    hostPort: 80
EOF
```

Next we will install Crossplane to provision infrastructure using a declarative approach.

## Installing Crossplane

Let's install [Crossplane](https://crossplane.io) into it's own namespace using Helm: 

```

helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

helm install crossplane --namespace crossplane-system --create-namespace crossplane-stable/crossplane --wait
```

```
kubectl crossplane install provider crossplane/provider-helm:v0.10.0
```

We need to get the correct ServiceAccount to create a new ClusterRoleBinding so the Helm Provider can install Charts on our behalf. 

```
SA=$(kubectl -n crossplane-system get sa -o name | grep provider-helm | sed -e 's|serviceaccount\/|crossplane-system:|g')
kubectl create clusterrolebinding provider-helm-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"
```

```
kubectl apply -f crossplane/config/helm-provider-config.yaml
```

Finally we will enable the paltform with Knative Serving, so we reduce the complexity of deploying our workloads and improve developer experience.

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
      port: 81
      targetPort: 8080
EOF
```

## Install ArgoCD

Let's install ArgoCD into our platform cluster with: 

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```


You can access the ArgoCD installation by using `kubectl port-forward`:

```
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

And you can get the admin password by running the following command: 

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

### Configure Production Cluster

This requires to have a production cluster ready, [you can follow the instructions here to get the production environment up and running](production-cluster.md). 

Let's now configure our production environment ArgoCD application: 

```
kubectl apply -f argocd/production-env.yaml -n argocd
```