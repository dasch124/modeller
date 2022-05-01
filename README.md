# Modeller
 
 This repo contains a XML schema + conversion scripts for quickly formulating a structured data model in a format-agnostic manner and transform it into human-readable documentation as html and/or docx.

## New model

```
> build.sh -a generateTemplates` generates template files as a starting point 
```

## Processing

```
> build.sh -a generateDocs -i model.xml
```

## Building and publishing the Docker image

```
> podman build . --tag ghcr.io/dasch124/modeller:v1_beta --no-cache
> podman login ghcr.io --username dasch124 --password-stdin < echo $GHCR_TOKEN
> podman push ghcr.io/dasch124/modeller:v1_beta

```

NB: just exchange `podman` with `docker` in case you are using that.

## Using the Docker image

Firstly, create a Dockerfile in your model's data directory: 

```
FROM ghcr.io/dasch124/modeller:v1_beta

WORKDIR /tmp

COPY ./*.xml .

RUN modeller/build.sh -a generateDocs -i model.xml -o index -v -l debug.log
```


