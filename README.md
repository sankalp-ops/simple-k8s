# simple-k8s

Current manual steps to deploy app after running terraform apply:

1) Download Kubeconfig file of EKS cluster:
   - Run  aws eks update-kubeconfig   --name <Cluster Name>   --region <Region>   --kubeconfig <Path to download kubeconfig to>

2) Enable Ingress on EKS:
    - Install Helm
    - Run helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    - Run helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx  --namespace ingress-nginx --create-namespace   --set-string controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" --kubeconfig <Path of kubeconfig of EKS>

3) Make gp2 storageclass as default(need to check if we can fix):
     -  Run kubectl --kubeconfig <path to kubeconfig of EKS> patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}', or you can storageClassName: gp2 in pvc yaml definition.
      
4) Disable IMDSv2(need to fix this too):
     - With the new CSI driver addon being installed to provision our PVC, our way of attaching an IAM Role to the Worker Group instances(which is a legacy way) is not able to provision the EBS volume as it is expecting IMDSV2. This needs to be fixed by using IRSA but to get the app working, have temporarily disabled IMDSV2. The command to do it - aws ec2 modify-instance-metadata-options --instance-id <instance-id> --http-endpoint enabled --http-tokens optional --http-put-response-hop-limit 2. Do this for all worker group instances.
  
Following these manual steps and then running kubectl apply --kubeconfig <path to kubeconfig of EKS> will get the app working on the Load Balancer arn.
