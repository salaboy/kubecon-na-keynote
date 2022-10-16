# Use Case / Story

You work for a company that specialize in providing Rainbows-as-a-Service (commonly known as RaaS). The company realized that in order to stay ahead of the competition they need to innovate and created a new team to add a game changing feature.

The team is tasked to add **Spiders** to the rainbows service! 
The new team is comformed by the best of the best and they decide to call themselves the amazing **Arachnid Team**.

On this tutorial you will work for the **Arachnid Team** and interact with the Rainbows-as-a Service Internal Development Platform (IDP) to request a new Environment to create and deploy a function (called **spiderize**) to implement this game changing feature.

Once the function is tested and working as expected, the platform should pave the way to production. On this tutorial, the platform team will be using ArgoCD to promote changes to the production environment without interacting directly with the production cluster. At the end of this tutorial you should have experienced the following key interactions: 
- Requesting a new Environment to the Internal Development Platform
- Creating and deploying a function without writing any Dockerfile or YAML files
- Promoting the function to production without direct interaction with the Production Cluster