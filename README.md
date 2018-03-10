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

### Helm ingresses

The Chart provides ingress configuration to allow customization the installation by adapting
the `config.yaml` depending on your setup. Please read the comments in the value.yaml file for more
detail on how to configure your reverse proxy.

### Prefix

This Helm automatically prefixes all names using the release name to avoid collisions.

### URL prefix

This chart exposes 2 endpoints:

- Airflow Web UI
- Flower, a debug UI for Celery

Both can be placed either at the root of a domain or at a sub path, for example:

```
http://mycompany.com/airflow/
http://mycompany.com/airflow/flower
```

NOTE: Mounting the Airflow UI under a subpath requires an airflow version > 1.9.x. For the moment
(March 2018) this is **not** available on official package, you will have to use an image where 
airflow has been updated to its current HEAD. You can use the following one: 
`stibbons31/docker-airflow-dev:2.0dev`

Please also note than Airflow UI and Flower do not behave the same:

- Airflow Web UI behave transparently, to configure it one just need to specify the `ingress.web.path` value.
- Flower cannot handle this scheme directly and requires to use an URL rewrite mechanism in front of it. In short, it is able to generate the right URLs in the returned HTML file but cannot respond to these URL. It is commonly found in software that wasn't intended to work under something else than a root URL or localhost port. To use it, see the `value.yaml` in detail on how to configure your ingress controller to rewrite the URL (or "strip" the prefix path)

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

## Run with minikube (wihtout ingres)

You can start a test on minikube using the following commands:

```bash
make minikube-start
make dashboard
make helm-install-traefik
make helm-init
make test
make update-etc-host
make minikube-service-list
```

You can browse to the airflow webserver using:

```bash
make minikube-browse-web
```

Airflow webserver is not mounted at the root of the URL. You need to append `/airflow` to the 
opened window:

```
http://192.168.99.100:31706/airflow/
```

Flower is also configured in a subpath of the URL: `/airflow/flower`. But it behaves badly if a
reverse proxy is not properly configured. You can see a full description in the
`test/minikube-values.yaml` file. 
In this example, the expected behavior is:

- Flower appears at the root for example:
  
  ```
  http://192.168.99.100:32677/
  ``` 

- Links point to the subpath, for instance:

  ```
  http://192.168.99.100:32677/airflow/flower/tasks
  ```

  Instead of:
  
  ```
  http://192.168.99.100:32677/tasks
  ```

## Run with minikube (with Ingres)

This example is actually configured to use Traefik as ingress controler that perform the reverse 
proxy operations, especially for Flower where it is tricky.

For example, if we have this list of available services:

```bash
$ make minikube-service-list
minikube service list
|-------------|-------------------------|--------------------------------|
|  NAMESPACE  |          NAME           |              URL               |
|-------------|-------------------------|--------------------------------|
| airflow-dev | airflow-flower          | http://192.168.99.100:32088    |
| airflow-dev | airflow-postgresql      | No node port                   |
| airflow-dev | airflow-redis           | No node port                   |
| airflow-dev | airflow-web             | http://192.168.99.100:30189    |
| airflow-dev | airflow-worker          | No node port                   |
| default     | kubernetes              | No node port                   |
| kube-system | default-http-backend    | http://192.168.99.100:30001    |
| kube-system | kube-dns                | No node port                   |
| kube-system | kubernetes-dashboard    | http://192.168.99.100:30000    |
| kube-system | tiller-deploy           | No node port                   |
| kube-system | traefik-ingress-service | http://192.168.99.100:31333    |
|             |                         | http://192.168.99.100:30616    |
| kube-system | traefik-web-ui          | No node port                   |
|-------------|-------------------------|--------------------------------|
```

The line that interest us is the port of the first IP exposed by `traefik-web-ui`. It is the
main ingress. If will not be port 80 because of the way minikube works.

The second port is the Traefik dashboard.

Given you have your `/etc/host` properly set (ex: by `make update-etc-host`):

```bash
$ cat /etc/hosts
192.168.99.100 minikube traeffik-ui.minikube
```

You can then manually go to the following URL:

- Airflow Web server: http://minikube:31333/airflow/admin/
- Flower: http://minikube:31333/airflow/flower/

And see how both behave nicely !

## Scale the number of workers

Udate the value for the `celery.num_workers` then:

```bash
make helm-upgrade
```

# Wanna help?

Fork, improve and PR. ;-)
