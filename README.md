# Modeller
 
This repo contains a XML schema + conversion scripts for quickly formulating a structured data model in a format-agnostic manner and transform it into human-readable documentation as html and/or docx.

## Setup

Run … 

```
> build.sh -a install
```

… to install the necessary dependencies on your machine. **Please be aware: The setup script assumes you use `dnf` as your package manager. This has only be tested on Fedora 35 so far.** If you don't want to tinker with installing the necessary packages on your system, use the Docker image (see below).

## New model

In order to start the work on a new model, you can generate some stubs which provide you with an outline of the necessary XML structure:

```
> build.sh -a generateTemplates`
```

Otherwise, clone this repository and manually copy the files in the templates directory. Please note that you need to set the path to the RNG schema by hand.


## Processing

After you have added the information you needed, you can run

```
> build.sh -a generateDocs -i model.xml
```
 

## Using the Docker image

Firstly, create a Dockerfile in your model's data directory: 

```
FROM ghcr.io/dasch124/modeller:v1_beta

WORKDIR /tmp

COPY ./*.xml .

RUN modeller/build.sh -a generateDocs -i model.xml -o index -v -l debug.log
```


# Building and publishing the Docker image

Note to self:

```
> podman build . --tag ghcr.io/dasch124/modeller:v1_beta --no-cache
> podman login ghcr.io --username dasch124 --password-stdin < echo $GHCR_TOKEN
> podman push ghcr.io/dasch124/modeller:v1_beta
       
```

NB: just exchange `podman` with `docker` in case you are using that.
