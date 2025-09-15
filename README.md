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
  
3) Create ServiceAccount for ExternalDNS:
     - Create Namespace - **kubectl create ns external-dns --kubeconfig "Path to EKS kubeconfig"**
     - Run **kubectl apply -f "./k8s-apps/service-account.yaml" --kubeconfig "Path to EKS kubeconfig"**

4) Enable ExternalDNS on EKS:
     - Run **helm repo add bitnami https://charts.bitnami.com/bitnami**
     - Run **helm upgrade --install external-dns bitnami/external-dns   --namespace external-dns   --set provider=aws   --set policy=upsert-only   --set registry=txt   --set txtOwnerId=my-cluster   --set domainFilters={myfibapp.xyz}  --set serviceAccount.create=false  --set serviceAccount.name=external-dns --create-namespace --kubeconfig ./kubeconfig-eks**

5) Enable CertManager on EKS:
     - Run **helm repo add jetstack https://charts.jetstack.io**
     - Run **helm upgrade --install cert-manager jetstack/cert-manager   --namespace cert-manager --create-namespace   --set installCRDs=true  --kubeconfig "./kubeconfig-eks"**
   



  
Following these manual steps and then running kubectl apply --kubeconfig "path to kubeconfig of EKS" will get the app working on the Route53 domain.
