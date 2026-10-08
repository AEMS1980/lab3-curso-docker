pipeline {
  agent {
    kubernetes {
      cloud 'kubernetes'
      namespace 'jenkins'
      yamlFile 'agent.yaml'
      defaultContainer 'node'
    }
  }
  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 40, unit: 'MINUTES')
  }
  parameters {
    string(name: 'DOCKERHUB_USER', defaultValue: '', description: 'Tu usuario real de Docker Hub, en minúsculas')
    string(name: 'APP_VERSION', defaultValue: '3.0.0', description: 'Tag adicional de versión')
    string(name: 'KUBECTL_VERSION', defaultValue: 'v1.34.0', description: 'Ajustar a la versión del servidor: kubectl version')
  }
  environment {
    GHCR_IMAGE = 'ghcr.io/aems1980/tarea-final'
    IMAGE_TAG = 'augusto-martinez'
    NS = 'ns-augusto-martinez'
  }
  stages {
    stage('install') {
      steps {
        sh '''
          set -eu
          printf '%s' "$DOCKERHUB_USER" | grep -Eq '^[a-z0-9][a-z0-9_-]+$'
          printf '%s' "$APP_VERSION" | grep -Eq '^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$'
          printf '%s' "$KUBECTL_VERSION" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'
          npm install --global pnpm@10.11.0
          pnpm install --frozen-lockfile
          mkdir -p .tools
          case "$(uname -m)" in x86_64) arch=amd64;; aarch64) arch=arm64;; *) exit 1;; esac
          curl -fsSL "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/$arch/kubectl" -o .tools/kubectl
          curl -fsSL "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/$arch/kubectl.sha256" -o .tools/kubectl.sha256
          (cd .tools; printf '%s  kubectl\n' "$(cat kubectl.sha256)" | sha256sum -c -)
          chmod +x .tools/kubectl
        '''
      }
    }
    stage('test') {
      steps {
        sh 'pnpm test --runInBand && pnpm test:e2e --runInBand'
      }
    }
    stage('build') {
      steps {
        sh 'pnpm build'
        container('docker') {
          sh '''
            set -eu
            for i in $(seq 1 60); do docker info >/dev/null 2>&1 && break; sleep 2; done
            docker info >/dev/null
            docker build -t "$DOCKERHUB_USER/tarea-final:$IMAGE_TAG" .
            docker tag "$DOCKERHUB_USER/tarea-final:$IMAGE_TAG" "$DOCKERHUB_USER/tarea-final:$APP_VERSION"
            docker tag "$DOCKERHUB_USER/tarea-final:$IMAGE_TAG" "$GHCR_IMAGE:$IMAGE_TAG"
            docker tag "$DOCKERHUB_USER/tarea-final:$IMAGE_TAG" "$GHCR_IMAGE:$APP_VERSION"
          '''
        }
      }
    }
    stage('push') {
      steps {
        container('docker') {
          withCredentials([
            usernamePassword(credentialsId: 'dockerhub-augusto', usernameVariable: 'DH_USER', passwordVariable: 'DH_TOKEN'),
            usernamePassword(credentialsId: 'ghcr-augusto', usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN')
          ]) {
            sh '''
              set +x
              set -eu
              export DOCKER_CONFIG="$(mktemp -d)"
              trap 'rm -rf "$DOCKER_CONFIG"' EXIT
              test "$DH_USER" = "$DOCKERHUB_USER"
              printf '%s' "$DH_TOKEN" | docker login -u "$DH_USER" --password-stdin
              printf '%s' "$GH_TOKEN" | docker login ghcr.io -u "$GH_USER" --password-stdin
              docker push "$DOCKERHUB_USER/tarea-final:$IMAGE_TAG"
              docker push "$DOCKERHUB_USER/tarea-final:$APP_VERSION"
              docker push "$GHCR_IMAGE:$IMAGE_TAG"
              docker push "$GHCR_IMAGE:$APP_VERSION"
            '''
          }
        }
      }
    }
    stage('deploy') {
      steps {
        sh '''
          set -eu
          mkdir -p .rendered evidencias
          sed "s|TU_USUARIO_DOCKERHUB|$DOCKERHUB_USER|g" entrega.yaml > .rendered/entrega.yaml
          # El Namespace ya fue creado por el administrador; el agente tiene permisos locales.
          sed '1,/^---$/d' .rendered/entrega.yaml | .tools/kubectl apply -f -
          # Mismo tag personal: forzar renovación incluso cuando el manifiesto no cambia.
          .tools/kubectl rollout restart deployment/app-augusto-martinez -n "$NS"
          .tools/kubectl rollout status deployment/app-augusto-martinez -n "$NS" --timeout=180s
          .tools/kubectl get pods,deployments,services -n "$NS" > evidencias/pipeline-recursos.txt
          curl --fail --silent --show-error --retry 10 --retry-all-errors --retry-delay 3 \
            "http://svc-augusto-martinez.$NS.svc.cluster.local/lab" > evidencias/pipeline-lab.json
          node -e 'const f=require("fs"); const x=JSON.parse(f.readFileSync("evidencias/pipeline-lab.json")); if(x.AMBIENTE!=="laboratorio-augusto-martinez" || x.API_KEY!=="demo-lab3-augusto-sin-valor-real") process.exit(1)'
        '''
      }
    }
  }
  post {
    always {
      archiveArtifacts artifacts: 'evidencias/pipeline-*', allowEmptyArchive: true
    }
  }
}
