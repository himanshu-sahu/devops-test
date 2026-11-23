# ACEest Fitness & Gym DevOps Assignment

This project implements a simple Flask application for the ACEest Fitness & Gym assignment and demonstrates a basic DevOps workflow using Git, GitHub Actions, Docker, and Jenkins.

## Project Objective

The application is designed to simulate a small gym management system and includes:

- Flask web endpoints for a fitness business
- A test suite using Pytest
- Docker containerization
- CI pipeline automation through GitHub Actions
- Jenkins pipeline support for build validation

## Features

- `GET /` - landing page for the gym
- `GET /health` - health check endpoint
- `GET /members` - list all members
- `GET /plans` - list membership plans
- `POST /checkin` - marks a member as checked in

## Local Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/himanshu-sahu/devops-test.git
   cd devops-test
   ```

2. Create and activate a virtual environment:

   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   ```

3. Install dependencies:

   ```bash
   pip install -r requirements.txt
   ```

4. Run the Flask app:

   ```bash
   python app.py
   ```

5. Open the app in a browser:
   ```text
   http://localhost:5000
   ```

## Run Tests Manually

```bash
python -m pytest -q
```

## Docker Build and Run

Build the image:

```bash
docker build -t aceest-fitness-gym .
```

Run the container:

```bash
docker run -p 5000:5000 aceest-fitness-gym
```

## GitHub Actions Workflow

The workflow in `.github/workflows/main.yml` is triggered on pushes and pull requests to any branch. It performs the following steps:

1. Checks out the code
2. Sets up Python 3.12
3. Installs dependencies from `requirements.txt`
4. Runs a syntax check with `compileall`
5. Executes the Pytest suite
6. Builds the Docker image using `requirements.txt`

The workflow validates and builds the image; it does not publish the image or deploy the application.

## Jenkins Integration

The included `Jenkinsfile` defines a build pipeline that does the following:

1. Checks out the configured SCM repository and installs project dependencies
2. Runs the test suite
3. Runs SonarQube static analysis
4. Waits for the SonarQube Quality Gate and fails the pipeline if it does not pass
5. Builds the Docker image
6. Replaces the `aceest-fitness-gym` container and deploys it on port 5001

To run it, create a Jenkins Pipeline job (or Multibranch Pipeline), configure its SCM URL as `https://github.com/himanshu-sahu/devops-test.git`, and use the repository's `Jenkinsfile`. Install the SonarQube Scanner Jenkins plugin, configure a SonarQube server named `SonarQube` and a scanner installation named `SonarScanner` in Jenkins, and add the SonarQube token as a Jenkins Secret text credential with the ID `sonar-qube-token`. Configure the SonarQube server webhook to point to `https://<jenkins-url>/sonarqube-webhook/`. The project key and source/test paths are defined in `sonar-project.properties`. The pipeline requires the webhook so Jenkins can receive the Quality Gate result; it aborts if the gate does not pass or if no result is received within five minutes. After a successful deployment, the app is available at `http://localhost:5001`.

For a Pipeline job configured with SCM, the `Jenkinsfile` polls the repository every five minutes and starts a build when it detects changes. Alternatively, configure a GitHub webhook if Jenkins has a publicly reachable URL. Public repository access does not require GitHub credentials; private repositories do.

The Jenkins agent must have Python 3, the Docker CLI, `kubectl` (on `PATH`), and permission to use a Docker daemon and Kubernetes cluster. Configure the agent's Kubernetes context or provide a Jenkins kubeconfig Secret file as `KUBECONFIG`. The deployment script checks for both `kubectl` and cluster connectivity before changing resources. If `kubectl` is installed outside `PATH`, set the `KUBECTL` environment variable to its executable path. If Jenkins runs in a container, configure Docker socket access and make the Kubernetes configuration available to the Jenkins process; the pipeline cannot grant those host-level permissions itself.

## Kubernetes Deployment

The Kubernetes manifests are in `k8s/` and deploy two application replicas in the `aceest` namespace. The service exposes the application on Minikube through NodePort `30001`.

Deploy to Minikube:

```bash
eval $(minikube docker-env)
docker build -t aceest-fitness-gym:latest .
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
minikube service aceest-fitness-gym -n aceest
```

## Deployment Strategies

Use `./scripts/kubernetes-deploy.sh <strategy>`:

- `rolling`: updates the stable deployment with zero unavailable replicas.
- `blue-green`: starts the candidate deployment, verifies it, and switches the public service selector to candidate.
- `canary`: installs the NGINX candidate Ingress. Add `X-Canary: always` to route a request to the candidate.
- `shadow`: mirrors stable traffic to the candidate while returning only stable responses.
- `a-b`: routes users sending `X-AB-Group: B` to the candidate; others remain on the stable version.
- `rollback`: restores the last Kubernetes revision and points the public service back to stable.

Set `ROLLBACK_ON_FAILURE=true` to automatically restore the stable deployment if rollout or verification fails. The Jenkins pipeline exposes the strategy and rollback behavior as build parameters.

## Assignment Reflection

This project follows the DevOps assignment goals by demonstrating:

- version control readiness with Git
- automated validation with tests
- predictable deployment using Docker
- pipeline automation using GitHub Actions and Jenkins
- clear documentation for onboarding and maintenance

## License

This project is for academic learning and assignment submission purposes.
