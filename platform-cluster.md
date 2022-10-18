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

## Creating the `production` namespace

You can create the production namespace by running: 

```
kubectl create ns production
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
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.7.2/serving-core.yaml

```

Installing the networking stack to support advanced traffic management: 

```
kubectl apply -f https://github.com/knative/net-kourier/releases/download/knative-v1.7.0/kourier.yaml

```

```
kubectl patch configmap/config-network \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"ingress-class":"kourier.ingress.networking.knative.dev"}}'

```

Configuring domain mappings: 

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

## Install ArgoCD

Let's install ArgoCD into our platform cluster with: 

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```


You can access the ArgoCD dashboard by using `kubectl port-forward` (in a separate terminal):

```
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then you can point your browser to [http://localhost:8080](http://localhost:8080)

And you can get the `admin` user's password by running the following command: 

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

### Configure Production Environment (namespace)

To simplify the demo, we will create a `production` namespace inside our platform cluster. In real life scenarios, it will be recommended to configure a seaprate cluster for sensitive environments. [You can check this guide to connect ArgoCD to an external cluster](production-cluster.md).


Let's now configure our production environment ArgoCD application. The following file points to a [GitHub repository](https://github.com/salaboy/kubecon-production) that contains our production environment configurations. Feel free to change and use your own repository and then run: 

```
kubectl apply -f argocd/production-env.yaml -n argocd
```

You should  be able to see the `Production Environment` ArgoCD application in the dashboard. Feel free to sync it now and see if the application gets deployed to the production environment. If you are running on KinD, the URL of the application running in the `production` environment should be this one [http://app.production.127.0.0.1.sslip.io](http://app.production.127.0.0.1.sslip.io)

[Now you can get back to the main tutorial to configure our Platform resources](README.md#configuring-our-platform-cluster).