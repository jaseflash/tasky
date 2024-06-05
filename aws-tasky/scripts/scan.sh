#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
# K8s Namespace Permissions Audit
echo "Running NamespaceHound on tasky namespace"
python3 /Users/jasonbroadbent/Projects/security/namespacehound/nshound.py --kubeconfig /Users/jasonbroadbent/.kube/config -o table
#python3 /Users/jasonbroadbent/Projects/security/namespacehound/nshound.py --kubeconfig /Users/jasonbroadbent/.kube/config -n tasky -o table
#python3 /Users/jasonbroadbent/Projects/security/namespacehound/nshound.py --kubeconfig /Users/jasonbroadbent/.kube/config -c -o table
echo
echo "Running trivy image scan on tasky"
trivy image --severity HIGH,CRITICAL jaseflash1234/tasky:1.3
echo
echo "Running trivy k8s deployment scan on tasky namespace"
trivy k8s --namespace=tasky --report=summary deploy
echo
echo "Running trivy aws scan to see S3 bucket findings"
trivy aws
echo "running trivy repo scan on aws-tasky"
trivy repo ${SCRIPT_DIR}/../../aws-tasky