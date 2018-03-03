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

The deployment uses the Trick decribed here to force reployment when the configmap template file
change:
https://github.com/kubernetes/helm/blob/master/docs/charts_tips_and_tricks.md#automatically-roll-deployments-when-configmaps-or-secrets-change

But this does not trigger a redeployment when any of the values templated inside this configmap
changes (see https://github.com/kubernetes/helm/issues/3601).
If you want to automatize the reployment when the configmap change, you need to use the
Fabric8's Configmap controller: https://github.com/fabric8io/configmapcontroller/
This Helm already carries the annotations.

### Helm ingresses

The Chart provides ingress configuration to allow customization the installation by adapting
the `config.yaml` depending on your setup.

### Prefix

This Helm automatically prefixes all names using the release name to avoid collisions.

### DAGs deployment: embedded DAGs or git-sync

This chart provide basically two way of deploying DAGs in your Airflow installation:

- embedded DAGs
- Git-Sync

This helm chart provide support for Persistant Storage but not for sidecar git-sync pod.
If you are willing to contribute, do not hesitate to do a Pull Request !

#### Using embedded Git-Sync

Git-sync is the easiest way to automatically update your DAGs. It simply checks periodically (by
default every minute) a Git project on a given branch and check this new version out when available.
Scheduler and worker see changes almost real-time. There is no need to other tool and complex
rolling-update procedure.

While it is extremely cool to see its DAG appears on Airflow 60s after merge on this project, you should be aware of some limitations Airflow has with dynamic DAG updates:

    If the scheduler reloads a dag in the middle of a dagrun then the dagrun will actually start
    using the new version of the dag in the middle of execution.

This is a known issue with airflow and it means it's unsafe in general to use a git-sync
like solution with airflow without:

 - using explicit locking, ie never pull down a new dag if a dagrun is in progress
 - make dags immutable, never modify your dag always make a new one

Also keep in mind using git-sync may not be scalable at all in production if you have lot of DAGs.
The best way to deploy you DAG is to build a new docker image containing all the DAG and their
dependencies. To do so, fork this project

#### Worker Statefulset

As you can see, Celery workers uses StatefulSet instead of deployment. It is used to freeze their
DNS using a Kubernetes Headless Service, and allow the webserver to requests the logs from each
workers individually. This requires to expose a port (8793) and ensure the pod DNS is accessible to
the web server pod, which is why StatefulSet is for.

#### Embedded DAGs

If you want more control on the way you deploy your DAGs, you can use embedded DAGs, where DAGs
are burned inside the Docker container deployed as Scheduler and Workers.

Be aware this requirement more heavy tooling than using git-sync, especially if you use CI/CD:

- your CI/CD should be able to build a new docker image each time your DAGs are updated.
- your CI/CD should be able to control the deployment of this new image in your kubernetes cluster

Example of procedure:
- Fork this project
- Place your DAG inside the `dags` folder of this project, update `requirements-dags.txt` to
  install new dependencies if needed (see bellow)
- Add build script connected to your CI that will build the new docker image
- Deploy on your Kubernetes cluster

You can avoid forking this project by:

- keep a git-project dedicated to storing only your DAGs + dedicated `requirements.txt`
- you can gate any change to DAGs in your CI (unittest, `pip install -r requirements-dags.txt`,.. )
- have your CI/CD makes a new docker image after each successful merge using

      DAG_PATH=$PWD
      cd /path/to/kube-aiflow
      make ENBEDDED_DAGS_LOCATION=$DAG_PATH

- trigger the deployment on this new image on your Kubernetes infrastructure

### Python dependencies

If you want to add specific python dependencies to use in your DAGs, you simply declare them inside
the `requirements/dags.txt` file. They will be automatically installed inside the container during
build, so you can directly use these library in your DAGs.

To use another file, call:

    make REQUIREMENTS_TXT_LOCATION=/path/to/you/dags/requirements.txt

Please note this requires you set up the same tooling environment in your CI/CD that when using
Embedded DAGs.

### Helm configuration customization

Helm allow to overload the configuration to adapt to your environment. You probably want to specify
your own ingress configuration for instance.

## Run with minikube

You can browse the Airflow dashboard via running:

    make minikube-start
    make test
    make browse-web

the Flower dashboard via running:

    make browse-flower

If you want to use Ad hoc query, make sure you've configured connections:
Go to Admin -> Connections and Edit "mysql_default" set this values (equivalent to values in `config/airflow.cfg`) :
- Host : mysql
- Schema : airflow
- Login : airflow
- Password : airflow

Check [Airflow Documentation](http://pythonhosted.org/airflow/)

## Run the test "tutorial"

        kubectl exec web-<id> --namespace airflow-dev airflow backfill tutorial -s 2015-05-01 -e 2015-06-01

## Scale the number of workers

For now, update the value for the `replicas` field of the deployment you want to scale and then:

        make apply


# Wanna help?

Fork, improve and PR. ;-)
