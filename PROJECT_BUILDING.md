# How I started the project

## Prompt: intialize the terraform task project

```md
I have task for a DevOps position I want to achieve the home task provided.
I have some experience but need help guidence to task done.

Here is the role task pdf: PDF ATTACHMENT
```

## Prompt: intiialize python projects

```md
use UV to initiate a python Langchain project to create simple resume agent helper to be consumed by other services.
under python/resume-agent folder.
```

## Prompt: intiialize typescript projects

Manually used better-t-stack to initiate the project.

## Prompt: Creating Dockerfile for both apps.

```md
Here is offical Dockerfile example from the turborepo docs: https://turborepo.dev/docs/guides/tools/docker
The example there is using nextjs but can be adapted to both apps.
See if there is need for modifications
```

## Prompt: Aligning new projects to cluster.

```md
TASK:
Align all projects to k8s cluster.

PRE CONTEXT:
Ive added 2 sub monorepos for python/ and typescript/ both containing Docker files for each application. They need to be part of the cluster making the web application to accessing their internal services.
Need to introduce a Postgres DB as if its a managed db from aws (but locally in kind).
All project is running locally as if its in a cloud k8s, need to somewhere store docker images of services (My assumption may just use kind to store images)
Use "act" to run CI/CD locally as if its deployed to github. running everything from the make file.

REQUIREMENTS:

- Production ready code.
- Each service should be deployable to the cluster by its own.
- Run CI/CD locally using "act" as if its deployed to github. running everything from the make file.
- Have single source of deployment (main make file can help running)
- Use Terraform to deploy the infrastructure.
- Have secrets management for the cluster (can be default but manageable)
- Have logs management for the cluster. (opentelemetry, grafana, prometheus, loki, etc.)
```

## Prompt: Align github actions to the project task requirements.

```md
GOAL:
Let the whole team be able to use infra and deploy easily only through github actions

TASK:
Refactor github/workflows completely (removing current even) and create new that are more relevant. To allow developers to work with the cluster only with the use of github action through "act" locally. try not touching the infra/ folder too much this task is focusing on usability of github workflows actions.

REQUIREMENTS / SUGGESTIONS:
I want to have some workflows for infra and infra updates
I want to have infra for dev teams working on projects
I want to have build and deploy for services (argumen service) that will deploy a specific service to the cluster using terraform only (probably needs image version tag input (web:v1.0.0 instead of always latest)).
```
