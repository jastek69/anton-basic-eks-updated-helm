# anton-basic-eks-updated
aws eks update-kubeconfig --region <your-region> --name <your-cluster-name>:To log in to your EKS cluster using the AWS CLI

choco install kubernetes-cli -y

brew install kubectl

kubectl config get-contexts:To see your list of Kubernetes contexts

kubectl config current-context:To just see the current context

kubectl config use-context <context-name>:To change 


# shorcut note: if you want to use "k" instead of kubectl
echo "alias k='kubectl'" >> ~/.bashrc




# Create a namespace
kubectl create ns my-first-ns

# Create a service account
kubectl create sa -n my-first-ns my-app-id

# Deploy your first pod
kubectl apply -f basic-pod.yaml

# Deploy your first deployment
kubectl apply -f basic-deployment.yaml

# Deploy your first service
kubectl apply -f basic-service.yaml

# View your active services to access your application
kubectl get svc -n my-first-ns




Prometheus
# Install 


# Helm install for Prometheus - use GitBash terminal
helm install monitoring prometheus-community/kube-prometheus-stack \
 --namespace observability --create-namespace \
 --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName="gp2" \
 --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage="50Gi" \
 --set prometheus.service.type=LoadBalancer \
 --set grafana.service.type=LoadBalancer \
 --set grafana.persistence.enabled=true \
 --set grafana.persistence.storageClassName="gp2" \
 --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName="gp2" \
 --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage="10Gi"


 kubectl --namespace observability get pods -l "release=monitoring"

k get sts -n observability


kubectl describe -n observability sts alertmanager-monitoring-kube-prometheus-alertmanager

kubectl --namespace observability get pods -l "releasemonitoring"



# Helm commands - check pods 
kubectl get pods -n kube-system

kubectl get svc -n observability





# Grafana Dashboard
echo "Grafana Dashboard: http://$(kubectl get svc monitoring-grafana -n observability -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):80"


echo "Prometheus Server: http://$(kubectl get svc monitoring-kube-prometheus-prometheus -n observability -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):9090"


# Note: change the output into json



# Tear Down
helm uninstall
helm uninstall monitoring -n observability

kubectl delete namespace observability

Or Go to console and uninstall the Load Balancers when doing destroy
https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#LoadBalancers:


Also check EBS volumes:
https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#Volumes:sort=desc:size
