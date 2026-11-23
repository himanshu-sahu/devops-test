#!/usr/bin/env bash
set -euo pipefail

STRATEGY="${1:-rolling}"
NAMESPACE="aceest"
APP="aceest-fitness-gym"
STABLE_DEPLOYMENT="$APP"
CANDIDATE_DEPLOYMENT="$APP-candidate"
ROLLBACK_ON_FAILURE="${ROLLBACK_ON_FAILURE:-true}"
IMAGE="${IMAGE:-aceest-fitness-gym:latest}"

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

rollback() {
  trap - ERR
  echo "Deployment failed; restoring the last stable version."
  kubectl rollout undo "deployment/$STABLE_DEPLOYMENT" -n "$NAMESPACE"
  kubectl rollout status "deployment/$STABLE_DEPLOYMENT" -n "$NAMESPACE" --timeout=180s
  kubectl patch service "$APP" -n "$NAMESPACE" --type merge \
    -p '{"spec":{"selector":{"app":"aceest-fitness-gym","deployment":"stable"}}}'
}

verify_candidate() {
  kubectl rollout status "deployment/$CANDIDATE_DEPLOYMENT" -n "$NAMESPACE" --timeout=180s
  kubectl run "$APP-verify-$$" -n "$NAMESPACE" --rm -i --restart=Never \
    --image=curlimages/curl:8.10.1 -- \
    curl --fail --retry 10 --retry-delay 2 \
    "http://$APP-candidate.$NAMESPACE.svc.cluster.local/health"
}

trap 'if [[ "$ROLLBACK_ON_FAILURE" == "true" ]]; then rollback; fi' ERR

case "$STRATEGY" in
  rolling)
    kubectl set image "deployment/$STABLE_DEPLOYMENT" \
      "$APP=$IMAGE" -n "$NAMESPACE"
    kubectl rollout status "deployment/$STABLE_DEPLOYMENT" -n "$NAMESPACE" --timeout=180s
    ;;

  blue-green)
    kubectl apply -f k8s/candidate-deployment.yaml
    kubectl apply -f k8s/candidate-service.yaml
    verify_candidate
    kubectl patch service "$APP" -n "$NAMESPACE" --type merge \
      -p '{"spec":{"selector":{"app":"aceest-fitness-gym","deployment":"candidate"}}}'
    echo "Blue-green switch complete. Green is live; blue remains available for rollback."
    ;;

  canary)
    kubectl apply -f k8s/candidate-deployment.yaml
    kubectl apply -f k8s/candidate-service.yaml
    verify_candidate
    kubectl apply -f k8s/strategies-ingress.yaml
    echo "Canary candidate verified. Send X-Canary: always to route to the candidate."
    ;;

  shadow)
    kubectl apply -f k8s/candidate-deployment.yaml
    kubectl apply -f k8s/candidate-service.yaml
    verify_candidate
    kubectl apply -f k8s/strategies-ingress.yaml
    kubectl patch ingress "$APP-stable" -n "$NAMESPACE" --type merge \
      -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/mirror-target":"http://aceest-fitness-gym-candidate.aceest.svc.cluster.local","nginx.ingress.kubernetes.io/mirror-host":"aceest-fitness-gym-candidate.aceest.svc.cluster.local"}}}'
    echo "Shadow traffic is mirrored to the candidate without affecting responses."
    ;;

  a-b)
    kubectl apply -f k8s/candidate-deployment.yaml
    kubectl apply -f k8s/candidate-service.yaml
    verify_candidate
    kubectl apply -f k8s/strategies-ingress.yaml
    kubectl patch ingress "$APP" -n "$NAMESPACE" --type merge \
      -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-by-header":"X-AB-Group","nginx.ingress.kubernetes.io/canary-by-header-value":"B","nginx.ingress.kubernetes.io/canary":"true"}}}'
    echo "A/B routing: header X-AB-Group=B gets variant B; all others receive variant A."
    ;;

  rollback)
    rollback
    ;;

  *)
    echo "Unknown strategy: $STRATEGY" >&2
    exit 2
    ;;
esac

trap - ERR
