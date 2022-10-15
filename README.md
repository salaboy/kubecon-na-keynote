# Kubecon North America 2022 :: Keynote Demo

In this step-by-step tutorial you will install and configure a set of Open Source projects that enable development teams to create **Environments** on-demand by just creating simple Kubernetes Resources. 

The tutorial uses [Crossplane](), the [Crossplane Helm Provider](), [VCluster]() and [Knative Serving]() to enable developers to create and deploy functions into the environments that they create.

You can read more about these projects and how they can be combined to build platforms in the  blog posts titled: **The challenges of building paltforms [1](),[2](),[3]() and [4]()**.

This step-by-step tutorial is divided into 5 sections
- [Use Case/Story]()
- [Prerequisites and Installation]()
- [Creating a new Environment]()
- [Creating and deploying a function]()
- [Our function goes to production]()

## Use Case / Story

You work for a company that specialize in providing Rainbows-as-a-Service. The company realized that in order to stay ahead of the competition they need to innovate and created a new team to add a game changing.

## Prerequisites and Installation 

This section covers the installation of the following components:

- Creating a Kubernetes Cluster for hosting the platform tools
- Installing Crossplane and Crossplane Helm Provider
- Installing Knative Serving
- Installing Command-line tools: 
    - VCluster CLI
    - Knative Functions CLI

First let's create a Kubernetes Cluster host the platform-wide tools using [KinD]():

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


Then let's install [Crossplane]() into it's own namespace using Helm: 


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

Then let's install Knative Serving in the platform cluster too: 

https://knative.dev/docs/install/yaml-install/serving/install-serving-with-yaml/#prerequisites


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

## Installing CLIs

On the developer laptop you need to install the following CLIs:

- Install the `vcluster` CLI to connect to the cluster: [https://www.vcluster.com/docs/getting-started/setup](https://www.vcluster.com/docs/getting-started/setup)
- Install the Knative Functions `func` CLI: [https://github.com/knative-sandbox/kn-plugin-func/blob/main/docs/installing_cli.md](https://github.com/knative-sandbox/kn-plugin-func/blob/main/docs/installing_cli.md)


## Installing Environment configurations

The Crossplane composition (XR) and the CRD for our `Environment` resource can be found inside the `crossplane` directory

These files define what needs to be provisioned when a new `Environment` resource is created.
The composition looks like this: 

![environment-vcluster-composition](environment-vcluster-composition.png)

Notice that we haven't installed anything VCluster specific, but the composition defines that a VCluster will be created for each **Environment** resource by installing the VCluster Helm chart. 


Let's apply the Crossplane Composition and our **Environment Custom Resource Definition (CRD)** into the Platform Cluster (host cluster in VCluster terms):
```
kubectl apply -f crossplane/composition-devenv.yaml
kubectl apply -f crossplane/environment-resource-definition.yaml
```

Check that no VCluster was created just yet.

```
vcluster list
```

Now let's go ahead and create a new **Arachnid Environment**:

```
kubectl apply -f arachnid-env.yaml
```

You can now treat your created environment resource as any other Kubernetes resource, you can list them using `kubectl get environments` or even describing them to see more details. 



You can go back and check if there is now a new VCluster with:

```
vcluster list 
```

Notice the VCluster is there but it shows not Connected, the Helm Provider connected to the VCluster from inside the cluster, but as users we can use the vcluster CLI to connect and interact with our freshly created VCluster 


```
vcluster connect arachnid-env --server https://localhost:8443 -- bash
```
or

```
vcluster connect arachnid-env --server https://localhost:8443 -- zsh
```


Now you are interacting with the VCluster, so you can use `kubectl` as usual. 


We can now create a function and deploy it to our freshly created **Arachnid Environment**.


## Creating and deploying a function

```
mkdir spiderize/
cd spiderize/

func create -r https://github.com/salaboy/func -l go -t spiders

func deploy -v --registry docker.io/<YOUR DOCKERHUB USER>

```

## Our function goes to production

We will now create a separate KinD Cluster to represent our **Production Environment**. This new Cluster will use ArgoCD to promote functions into the cluster. 

The idea here is not to interact with this cluster manually to deploy new functions, but use ArgoCD and a Git repository to host all the environment configurations. 

```
cat <<EOF | kind create cluster --name production --config=-
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

Then let's install Knative Serving: 

https://knative.dev/docs/install/yaml-install/serving/install-serving-with-yaml/#prerequisites

