# Kubecon North America 2022 :: Keynote Demo

In this step-by-step tutorial, you will install and configure a set of open source projects to create an Internal Development Platform (IDP) for a fictitious company. [You can read more about the use case here](use-case.md).  

The tutorial section ['Requesting a New Environment'](#requesting-a-new-environment) uses [Crossplane](https://crossplane.io), the [Crossplane Helm Provider](https://github.com/crossplane-contrib/provider-helm) and [VCluster](https://vcluster.com) to enable developers to request new environments in which to do their work. The ['Creating and Deploying a Function'](#creating-and-deploying-a-function) section uses [Knative Serving](https://knative.dev) and [Knative Functions](https://github.com/knative/func) to create and deploy a function into the environment that we created. Finally, the ['Our Function Goes to Production](#our-function-goes-to-production) section uses [ArgoCD](https://argoproj.github.io/cd) to promote the function that we have created to the production environment without requiring any teams to interact with the production cluster manually. 

You can read more about these projects and how they can be combined to build platforms in the  blog posts titled: **The Challenges of Building Platforms [1](https://salaboy.com/2022/09/29/the-challenges-of-platform-building-on-top-of-kubernetes-1-4/),[2](https://salaboy.com/2022/10/03/the-challenges-of-platform-building-on-top-of-kubernetes-2-4/),[3](https://salaboy.com/2022/10/17/the-challenges-of-platform-building-on-top-of-kubernetes-3-4/) and [4]()**.

This step-by-step tutorial is divided into 4 sections:
- [Prerequisites and Installation](#prerequisites-and-installation)
- [Requesting a New Environment](#requesting-a-new-environment)
- [Creating and Deploying a Function](#requesting-a-new-environment)
- [Our Function Goes to Production](#our-function-goes-to-production)


## Prerequisites and Installation 

This tutorial creates and interacts with Kubernetes clusters, as well as installs Helm Charts. Hence, the following tools are needed: 
- [Install `kubectl`](https://kubernetes.io/docs/tasks/tools/)
- [Install `helm`](https://helm.sh/docs/intro/install/) 
- [Install `docker`](https://docs.docker.com/engine/install/)

For this demo, we will create a Kubernetes cluster to host the platform tools which  create development environments. These tools use VCluster to create development environments in separate namespaces. We will also create one namespace for our Production Environment. For simplicity, this tutorial uses [KinD](https://kind.sigs.k8s.io/), but we encourage you to try the tutorial on a real Kubernetes cluster. 


> Note: This tutorial has been tested on [GCP](https://cloud.google.com/gcp) using separate clusters for the platform and the production environment. [You can get free credits here](https://github.com/learnk8s/free-kubernetes).


- [Installing Command-Line Tools](installing-clis.md)
- [Create a Platform Cluster & Install Tools](platform-cluster.md)
  

### Configuring Our Platform Cluster

For this demo, our platform will enable development teams to request new `Environment`s.

These `Environment`s can each be configured differently depending what the team needs to do. For this demo, we have created a [Crossplane Composition](https://crossplane.io/docs/v1.9/concepts/composition.html) that uses [VCluster](https://www.vcluster.com/) to create one virtual cluster per development environment requested. This enables a team to request their own isolated cluster so that they can work on features without clashing with other teams' work. 

For this to work, we need to create two things: the Custom Resource Definition (CRD) that defines the APIs for creating new `Environment`s, and the Crossplane Composition that defines the resources that will be created every time that a new `Environment` resource is created. 

Let's apply the Crossplane Composition and our **Environment Custom Resource Definition (CRD)** into the Platform Cluster:
```
kubectl apply -f crossplane/environment-resource-definition.yaml
kubectl apply -f crossplane/composition-devenv.yaml
```

The Crossplane Composition that we have defined and configured in our Platform Cluster uses the Crossplane Helm Provider to create a new VCluster for every `Environment` with `type: development`. The VCluster will be created inside the Platform Cluster, but it will provide its own isolated Kubernetes API Server for the team to interact with. 

The VCluster created for each development `Environment` is using the VCluster Knative Serving Plugin to enable teams to use Knative Serving inside the virtual cluster, but without having Knative Serving installed. The VCluster Knative Serving plugin shares the Knative Serving installation in the host cluster with all of the virtual clusters.

Now we are ready to request environments, deploy our applications/functions, and promote them to production. 

## Requesting a New Environment 

To use the platform to request a new `Environment`, you need to create a new `Environment` resource like this one: 

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

Next, send it to the Platform APIs using `kubectl`:

```
kubectl apply -f arachnid-env.yaml
```

You can now treat your created `Environment` resource as any other Kubernetes resource. You can list them using `kubectl get environments`, or even `kubectl describe` them to see more details. 

Because we are using VCluster, you can go back and check if there is now a new VCluster with this command:

```
vcluster list 
```

Notice the VCluster is there, but it is not connected.


We can now create a function and deploy it to our freshly created **Arachnid Environment**.

## Creating and Deploying a Function

Now that we have an environment let's create and deploy a function to it.

Before creating a function, let's make sure that we are connected to our **Arachnid Environment**: 

On Linux with `bash`:
```
vcluster connect arachnid-env --server https://localhost:8443 -- bash
```
or on Mac OSX with `zsh`:

```
vcluster connect arachnid-env --server https://localhost:8443 -- zsh
```

We just used VCluster to connect to our `Environment`, therefor now we can use `kubectl` as usual (try `kubectl get namespaces` to check that you are in a different cluster). But instead of using `kubectl`, we will use the [Knative Functions](https://github.com/knative/func) CLI to enable our developers to create functions without the need of writing Dockerfiles or YAML files. 

First let's create a new empty directory for the function:
```
mkdir functions/spiderize/
cd functions/spiderize/
```
Now we can use `func create` to scaffold a function using the `Go` programming language and a template called `spiders` that was defined inside the template repository [https://github.com/salaboy/func](https://github.com/salaboy/func)
```
func create -r https://github.com/salaboy/func -l go -t spiders
```

Feel free to open the function using your favourite IDE or editor.

We can deploy this function to our development environment by running: 

```
func deploy -v --registry docker.io/<YOUR DOCKERHUB USER>
```

Where the `--registry` flag is used to specify where to publish our container image. This is required to make sure that the target cluster can access the function's container image.

Before the command ends, it gives us the URL of where the function is running. Now we can copy the URL and open it in our browser. It should look like this: 

[http://spiderize-x-default-x-arachnid-env.arachnid-env.127.0.0.1.sslip.io](http://spiderize-x-default-x-arachnid-env.arachnid-env.127.0.0.1.sslip.io)


Voila! You have just created and deployed a function to the `arachnid-environment`. 
You are a trailblazer in the rainbows industry!


## Our Function Goes to Production

We have configured the production cluster to use ArgoCD to synchronize the configuration located into a GitHub repository to our production namespace. 

To deploy the function that we have just created to our production environment, we send a pull request to our production environment GitHub repository. This pull request contains the configuration required to deploy our function. 

Because Knative Functions use Knative Serving, we also need to add the Knative Serving Service YAML file to the production environment repository.
 
By sending a pull request with this YAML file, we can enable automated tests on the platform to check if the changes are production-ready. Once they are validated, the pull request can be merged. [Check this example pull request that changes the configuration of the application to use our new function image](https://github.com/salaboy/kubecon-production/pull/24/files). 

Once the changes are merged into the `main` branch of our repository, ArgoCD will sync these configuration changes. This causes our function to be deployed and automatically available for our users to interact with. 

We have used the following repository to host our production environment configuration: 
[https://github.com/salaboy/kubecon-production](https://github.com/salaboy/kubecon-production)

We recommend that you fork this repository, or create a new one and copy the contents. 

If you push new configuration changes inside the `/production` directory, you can use ArgoCD to sync these changes to the production cluster, without the need of using `kubectl` to the production namespace directly. 

@TODO: screenshots

Once the function is synced by ArgoCD you should be able to point your browser to [https://app.production.127.0.0.1.sslip.io/](https://app.production.127.0.0.1.sslip.io/) to see the new version of the application up and running! 

Our change made it to production! 

# Resources and Links

TBD


