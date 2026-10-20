// cyb3r-kub3n3t3s release pipeline
// source -> tests -> Snyk -> build -> Snyk -> push -> staging (k3s) -> APPROVAL -> production (EKS)

pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  triggers {
    pollSCM('H/2 * * * *')   // check GitHub for new commits about every 2 minutes
  }

  environment {
    REGISTRY    = 'cyb3rr'
    BASE_DOMAIN = '100.56.198.3.nip.io'
    PROD_HOST   = 'ac5666824c32048a7b1b25392d86cd31-873150263.us-east-1.elb.amazonaws.com'
    AWS_REGION  = 'us-east-1'
    EKS_CLUSTER = 'cyb3r-prod'
    APPS        = 'api web'
    SNYK_TOKEN  = credentials('snyk-token')
  }

  stages {

    stage('Prepare') {
      steps {
        script {
          env.TAG = env.GIT_COMMIT.substring(0, 7)
          currentBuild.displayName = "#${env.BUILD_NUMBER} ${env.TAG}"
        }
        echo "Releasing commit ${env.TAG}"
      }
    }

    stage('Unit Tests') {
      steps {
        sh '''
          python3 -m venv .venv
          . .venv/bin/activate
          pip install --quiet --upgrade pip
          for app in $APPS; do
            echo "=== Testing $app ==="
            pip install --quiet -r apps/$app/requirements.txt -r apps/$app/requirements-dev.txt
            (cd apps/$app && python -m pytest -q)
          done
        '''
      }
    }

    stage('Snyk: Dependencies') {
      steps {
        sh '''
          . .venv/bin/activate
          for app in $APPS; do
            echo "=== Snyk dependency scan: $app ==="
            snyk test --file=apps/$app/requirements.txt --package-manager=pip \
              --command=python3 --severity-threshold=high
          done
        '''
      }
    }

    stage('Build Images') {
      steps {
        sh '''
          for app in $APPS; do
            docker build --pull -t $REGISTRY/cyb3r-$app:$TAG apps/$app
          done
        '''
      }
    }

    stage('Snyk: Containers') {
      steps {
        sh '''
          for app in $APPS; do
            echo "=== Snyk container scan: $app ==="
            snyk container test $REGISTRY/cyb3r-$app:$TAG \
              --file=apps/$app/Dockerfile --severity-threshold=critical
          done
        '''
      }
    }

    stage('Snyk: Kubernetes IaC') {
      steps {
        sh 'snyk iac test k8s/ --severity-threshold=high'
      }
    }

    stage('Push Images') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                          usernameVariable: 'DH_USER',
                                          passwordVariable: 'DH_PASS')]) {
          sh '''
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
            for app in $APPS; do
              docker push $REGISTRY/cyb3r-$app:$TAG
            done
            docker logout
          '''
        }
      }
    }

    stage('Deploy: Staging (k3s)') {
      steps {
        script { deployTo('staging') }
      }
    }

    stage('Smoke Test: Staging') {
      steps {
        script { smokeTest('staging') }
      }
    }

    stage('Approval Gate') {
      steps {
        script {
          timeout(time: 30, unit: 'MINUTES') {
            env.APPROVER = input(
              id: 'PromoteToProd',
              message: "Staging is healthy on ${env.TAG}. Promote to PRODUCTION on EKS?",
              ok: 'Approve and deploy',
              submitter: 'release-approver',
              submitterParameter: 'APPROVER'
            )
          }
          echo "Approved by ${env.APPROVER}"
        }
      }
    }

    stage('Deploy: Production (EKS)') {
      steps {
        script {
          deployTo('production')
          smokeTest('production')
        }
      }
      post {
        failure {
          script { rollback('production') }
        }
      }
    }
  }

  post {
    success { echo "Release ${env.TAG} is LIVE on EKS (approved by ${env.APPROVER})." }
    failure { echo "Pipeline failed. Production was not changed, or it was rolled back." }
    aborted { echo "Release rejected or timed out at the approval gate. Production untouched." }
    always {
      sh 'docker image prune -f || true'
      deleteDir()
    }
  }
}

// ---------- helper functions ----------

// Picks the right cluster and the right way in for each environment.
def withCluster(String ns, Closure body) {
  if (ns == 'production') {
    // EKS: no stored key. The EC2 instance role gets a short-lived token from AWS.
    withEnv(["KUBECONFIG=${env.WORKSPACE}/.kube/eks-prod"]) {
      sh '''
        mkdir -p "$(dirname "$KUBECONFIG")"
        aws eks update-kubeconfig --name "$EKS_CLUSTER" --region "$AWS_REGION" --kubeconfig "$KUBECONFIG"
      '''
      body()
    }
  } else {
    // k3s staging: the limited deployer kubeconfig stored in Jenkins credentials
    withCredentials([file(credentialsId: 'k8s-deployer-kubeconfig', variable: 'KUBECONFIG')]) {
      body()
    }
  }
}

def deployTo(String ns) {
  withCluster(ns) {
    sh """
      kubectl kustomize k8s/overlays/${ns} \\
        | sed -e "s|__REGISTRY__|${env.REGISTRY}|g" \\
              -e "s|__TAG__|${env.TAG}|g" \\
              -e "s|__DOMAIN__|${env.BASE_DOMAIN}|g" \\
        | kubectl apply -f -
      kubectl -n ${ns} rollout status deployment/redis --timeout=180s
      kubectl -n ${ns} rollout status deployment/api --timeout=240s
      kubectl -n ${ns} rollout status deployment/web --timeout=240s
      kubectl -n ${ns} get pods -o wide
    """
  }
}

def smokeTest(String ns) {
  // Staging: hit the k3s server directly with the staging host name.
  // Production: hit the public AWS load balancer, exactly like a customer.
  def url    = (ns == 'production') ? "http://${env.PROD_HOST}/" : 'http://$NODE_IP/'
  def header = (ns == 'production') ? '' : "-H 'Host: staging.${env.BASE_DOMAIN}'"
  sh """
    NODE_IP=\$(hostname -I | awk '{print \$1}')
    for i in 1 2 3 4 5 6 7 8 9 10; do
      if curl -fsS ${header} ${url} | grep -q "${env.TAG}"; then
        echo "Smoke test passed: ${ns} is serving ${env.TAG}"
        exit 0
      fi
      echo "Waiting for ${ns} (attempt \$i of 10)..."
      sleep 6
    done
    echo "Smoke test FAILED for ${ns}"
    exit 1
  """
}

def rollback(String ns) {
  withCluster(ns) {
    sh """
      echo "Rolling ${ns} back to the previous version..."
      kubectl -n ${ns} rollout undo deployment/web || true
      kubectl -n ${ns} rollout undo deployment/api || true
    """
  }
}
