# simple-k8s

Terraform related manual steps.

1. Terraform init
2. Terraform plan
3. Terraform apply

Current manual steps to deploy app after running terraform apply:

1) Download Kubeconfig file of EKS cluster:
   - Run  aws eks update-kubeconfig   --name "Cluster Name"   --region "Region"   --kubeconfig "Path to download kubeconfig to"

2) Enable Ingress on EKS:
    - Install Helm
    - Run helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    - Run helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx  --namespace ingress-nginx --create-namespace   --set-string controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" --kubeconfig "Path of kubeconfig of EKS"



  
Following these manual steps and then running kubectl apply --kubeconfig "path to kubeconfig of EKS" will get the app working on the Load Balancer arn.
