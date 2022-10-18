# Kubecon North America 2022 :: Keynote Demo

In this step-by-step tutorial you will install and configure a set of Open Source projects to create an Internal Development Platform (IDP) for a fictisous company. [You can read more about the use case here](use-case.md).  

The tutorial's section [Requesting a new Environment](#requesting-a-new-environment) uses [Crossplane](https://crossplane.io), the [Crossplane Helm Provider](https://github.com/crossplane-contrib/provider-helm) and [VCluster](https://vcluster.com) to enable developers to request for new environments to do their work. The [Creating and deploying a function](#creating-and-deploying-a-function) section uses [Knative Serving](https://knative.dev) and [Knative Functions](https://github.com/knative/func) to create and deploy functions into these environments. Finally, the [Our function goes to production](#our-function-goes-to-production) section uses [ArgoCD](https://argoproj.github.io/cd) to promote the function that we have created to the production environment without requiring any teams to interact with the production cluster manually. 

You can read more about these projects and how they can be combined to build platforms in the  blog posts titled: **The challenges of building paltforms [1](https://salaboy.com/2022/09/29/the-challenges-of-platform-building-on-top-of-kubernetes-1-4/),[2](https://salaboy.com/2022/10/03/the-challenges-of-platform-building-on-top-of-kubernetes-2-4/),[3](https://salaboy.com/2022/10/17/the-challenges-of-platform-building-on-top-of-kubernetes-3-4/) and [4]()**.

This step-by-step tutorial is divided into 4 sections
- [Prerequisites and Installation](#prerequisites-and-installation)
- [Requesting a new Environment](#requesting-a-new-environment)
- [Creating and deploying a function](#requesting-a-new-environment)
- [Our function goes to production](#our-function-goes-to-production)


## Prerequisites and Installation 

This tutorial creates interact with Kubernetes clusters as well as install Helm Charts hence the following tools are needed: 
- [Install `kubectl`](https://kubernetes.io/docs/tasks/tools/)
- [Install `helm`](https://helm.sh/docs/intro/install/) 
- [Install `docker`](https://docs.docker.com/engine/install/)

For this demo we will create a Kubernetes Clusters to host the Platform tools which  create Development Environments in separate namespaces using VCluster and one namespace for our Production Environment. While this tutorial uses  [KinD](https://kind.sigs.k8s.io/) for simplicity, we encourage people to try the tutorial on real Kubernetes Clusters. 


> Note: This tutorial has been tested on [GCP](https://cloud.google.com/gcp)  and using separate clusters for the platform and the production ?environment. [You can always get free credits here](https://github.com/learnk8s/free-kubernetes).


- [Installing Command-line tools](installing-clis.md)
- [Create a Platform Cluster & Install Tools](platform-cluster.md)
  

### Configuring our Platform cluster

For this demo, our platform will enable development teams to request new `Environment`s.

These `Environment`s can be configured differently depending what the teams needs to do. For this demo, we have created a [Crossplane Composition](https://crossplane.io/docs/v1.9/concepts/composition.html) that uses [VCluster](https://www.vcluster.com/) to create one virtual cluster per Development environment requested. This enable the teams with their own isolated cluster to work on features without clashing with other teams work. 

For this to work we need to create the Custom Resource Definition (CRD) that defines the APIs for creating new `Environment`s and the Crossplanae Composition that define the resources that will be created every time that a new `Environment` resource is created. 

Let's apply the Crossplane Composition and our **Environment Custom Resource Definition (CRD)** into the Platform Cluster:
```
kubectl apply -f crossplane/environment-resource-definition.yaml
kubectl apply -f crossplane/composition-devenv.yaml
```

The Crossplane Composition that we have defined and configured in our Platform Cluster uses the Crossplane Helm Provider to create a new VCluster for every `Environment` with `type: development`. The VCluster will be created inside the Platform Cluster, but it will provide its own isolated Kubernetes API Server for the team to interact with. 

The VCluster created for each development `Environment` is using the Knative Serving Plugin to enable teams to use Knative Serving inside the virtual cluster, but without having Knative Serving installed. The VCluster Knative Serving plugin shares the Knative Serving installation in the host cluster with all the virtual clusters.

Now we are ready to request environments, deploy our applications/function and promote them to production. 

## Requesting a new Environment 

Requesting a new `Environment` to the platform is easy, you just need to create a new `Environment` resource like this one: 

```arachnid-env.yaml
apiVersion: salaboy.com/v1alpha1
kind: Environment
metadata:
  name: arachnid-env
spec:
  compositionSelector:
    matchLabels:
      type: development
  parameters: 
    spidersDatabase: true
    cacheEnabled: true
    secure: true
    
```

And send it to the Platform APIs using `kubectl`:

```
kubectl apply -f arachnid-env.yaml
```

You can now treat your created `Environment` resource as any other Kubernetes resource, you can list them using `kubectl get environments` or even describing them to see more details. 

Because we are using VCluster you can go back and check if there is now a new VCluster with:

```
vcluster list 
```

Notice the VCluster is there but it shows not Connected.


We can now create a function and deploy it to our freshly created **Arachnid Environment**.

## Creating and deploying a function

Now that we have an environment let's create and deploy function to it.

Before creating a function, let's make sure that we are connected to our **Arachnid Environment**: 

On linux with `bash`:
```
vcluster connect arachnid-env --server https://localhost:8443 -- bash
```
or on Mac OSX with `zsh`:

```
vcluster connect arachnid-env --server https://localhost:8443 -- zsh
```

Now you are connected with the VCluster of your `Environment`, so you can use `kubectl` as usual (try `kubectl get namespaces` to check that you are in a different cluster). But instead of using `kubectl` we will use the [Knative Functions](https://github.com/knative/func) CLI to enable our developers to create functions without the need of writing Dockerfiles or YAML files. 

First let's create a new empty directory for the function:
```
mkdir spiderize/
cd spiderize/
```
Now we can use `func create` to scaffold a function using the `Go` programming language and a template called `spiders` that was defined inside the template repository [https://github.com/salaboy/func](https://github.com/salaboy/func)
```
func create -r https://github.com/salaboy/func -l go -t spiders
```

Feel free to open the function using your favourite IDE or editor.

You can deploy this function to our development environment by running: 

```
func deploy -v --registry docker.io/<YOUR DOCKERHUB USER>
```

Where the `--registry` flag is used to specify where to publish our container image. This is required to make sure that the target cluster can access the function's container image.

Before the command ends it gives you the URL of where the function is running so you can copy the URL and open it in your browser. It should look like this: 

[]()


Voila! You have just created and deployed a function to the `arachnid-environment`. 
You are making the Rainbows industry rock again!


## Our function goes to production

We have configured the Production cluster to use ArgoCD to syncronize the configuration located into a GitHub repository to our Production namespace. 

To deploy the function that we have just created and deployed to our production environment we just need to send a Pull Request to our Production Environment GitHub repository only with the configuration required to deploy our function. 

Because Knative Functions are using Knative Serving, we just need to add the Knative Serving Service YAML file to the production environment repository.
 
By sending a Pull Request with this YAML file, we can enable automated tests on the platform to check if the changes are production ready and once they are validated the Pull Request can be merged. 

Once the changes are merged into the main branch of our repository ArgoCD will sync these configuration changes which causes our function to be deployed and automatically available for our users to interact with. 

We have used the following repository to host our production environment configuration: 
[https://github.com/salaboy/kubecon-production](https://github.com/salaboy/kubecon-production)

I recommend you to fork this repository or create a new one and copy the contents. 

If you push new configuration changes inside the `/production` directory you can use ArgoCD to sync these changes to the production cluster, without the need of using `kubectl` to the production namespace directly. 

@TODO: screenshots

Once the function is synced by ArgoCD you should be able to point your browser to [https://spiderize.production.127.0.0.1.sslip.io/](https://spiderize.production.127.0.0.1.sslip.io/)


