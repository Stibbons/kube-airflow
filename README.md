# Airflow Helm Chart

This repository contains a forked version of 
[mumoshu/kube-airflow](https://github.com/mumoshu/kube-airflow) providing a production ready Helm
chart for running Airflow with the Celery executor on a Kubernetes Cluster.

## Informations

* Based on work from [mumoshu/kube-airflow](https://github.com/mumoshu/kube-airflow)
* Leverage the Docker Airflow image [puckel/docker-airflow](https://github.com/puckel/docker-airflow)

## Helm Deployment

Ensure your helm installation is done, you may need to have `TILLER_NAMESPACE` set as
environment variable.

Deploy to Kubernetes using:

    make helm-upgrade HELM_RELEASE_NAME=af1 NAMESPACE=yournamespace HELM_VALUES=/path/to/your/own/values.yaml

The deployment uses the
[Helm's Trick decribed here](https://github.com/kubernetes/helm/blob/master/docs/charts_tips_and_tricks.md#automatically-roll-deployments-when-configmaps-or-secrets-change)
to force reployment when the configmap template file change.

But this does not trigger a redeployment when any of the values templated inside this configmap
changes (see issue [#3601](https://github.com/kubernetes/helm/issues/3601)).

If you want to automatize the reployment when the configmap change, you need to use the
[Fabric8's Configmap controller](https://github.com/fabric8io/configmapcontroller/).
This Helm already carries these annotations.

### Helm ingresses

The Chart provides ingress configuration to allow customization the installation by adapting
the `config.yaml` depending on your setup. Please read the comments in the value.yaml file for more
detail on how to configure your reverse proxy.

### Prefix

This Helm automatically prefixes all names using the release name to avoid collisions.

### Airflow configuration

`airflow.cfg` configuration can be changed by defining environment variables in the following form:
`AIRFLOW__<section>__<key>`.

See the
[Airflow documentation for more information](http://airflow.readthedocs.io/en/latest/configuration.html?highlight=__CORE__#setting-configuration-options)

This helm chart allows you to add these additional settings with the value key `airflow.config`.
But beware changing these values won't trigger a redeployment automatically (see the section above
"Helm Deployment"). You may need to force the redeployment in this case (`--recreate-pods`) or
use the [Configmap Controller](https://github.com/fabric8io/configmapcontroller/).

### Worker Statefulset

Celery workers uses StatefulSet instead of deployment.
It is used to freeze their DNS using a Kubernetes Headless Service, and allow the webserver to
requests the logs from each workers individually.
This requires to expose a port (8793) and ensure the pod DNS is accessible to the web server pod,
which is why StatefulSet is for.

### Embedded DAGs

If you want more control on the way you deploy your DAGs, you can use embedded DAGs, where DAGs
are burned inside the Docker container deployed as Scheduler and Workers.

Be aware this requirement more heavy tooling than using git-sync, especially if you use CI/CD:

- your CI/CD should be able to build a new docker image each time your DAGs are updated.
- your CI/CD should be able to control the deployment of this new image in your kubernetes cluster

Example of procedure:

- Fork this project
- Place your DAG inside the `dags` folder of this project, update `/requirements.txt` to
  install new dependencies if needed (see bellow)
- Add build script connected to your CI that will build the new docker image
- Deploy on your Kubernetes cluster

### Python dependencies

If you want to add specific python dependencies to use in your DAGs, you need to mount a
`/requirements.txt` file at the root of the image.
See the
[docker-airflow readme](https://github.com/puckel/docker-airflow#install-custom-python-package) for
more information.

## Makefile

This project uses a makefile to perform all major operation. It is mostly here as a reference to
see which commands need to be performed.

## Run with minikube

You can start a test on minikube using the following commands:

```bash
make minikube-start
make dashboard
make test
make minikube-browse-web
```

The Flower dashboard via running:

```bash
make minikube-browse-flower
```

## Scale the number of workers

Udate the value for the `celery.num_workers` then:

```bash
make helm-upgrade
```

# Wanna help?

Fork, improve and PR. ;-)
