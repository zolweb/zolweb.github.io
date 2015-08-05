---
layout: post
title: Docker sans utilisateur root sur l'hôte et dans les containers
author: yannick_pereirareis
excerpt: "Lorsqu'on travaille avec Docker, par défaut tout se fait en root : installation, lancement de commandes depuis l'hôte et lancement de commandes dans les containers. Mais ce comportement peut être modifié grâce à quelques configurations et lignes de commandes."
tags: [yannick pereira-reis, docker, user, utilisateur, root, container, makefile]
comments: true
image:
  feature: headers/docker.jpg
---

## Installation



L'installation de **docker** est très simple. Il suffit de suivre les instructions données dans la documentation.
Pour **ubuntu** par exemple, [la documentation](https://docs.docker.com/installation/ubuntulinux/) précise qu'il est
nécessaire de lancer la commande suivante :

{% highlight bash %}
wget -qO- https://get.docker.com/ | sh
{% endhighlight %}

Une fois l'execution de cette commande terminée, vous pouvez lancer très simplement votre premier container :

{% highlight bash %}
sudo docker run hello-world
{% endhighlight %}

Le résultat de cette commande devrait ressembler à quelque chose comme ça :

{% highlight bash %}
$ docker run hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from hello-world
a8219747be10: Pull complete 
91c95931e552: Already exists 
hello-world:latest: The image you are pulling has been verified. Important: image verification is a tech preview feature and should not be relied on to provide security.
Digest: sha256:aa03e5d0d5553b4c3473e89c8619cf79df368babd18681cf5daeb82aab55838d
Status: Downloaded newer image for hello-world:latest
Hello from Docker.
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (Assuming it was not already locally available.)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

For more examples and ideas, visit:
 http://docs.docker.com/userguide/
{% endhighlight %}

Mais voilà.... comme vous le voyez il est nécessaire d'avoir les privilèges **root** ! Au quotidien
cela est vraiment très pénalisant, surtout en mode développement, à moins de systématiquement travailler en tant qu'administrateur.
Mais il existe une solution pour travailler avec un utilisateur "normal" : 

* Créer un groupe **docker** (s'il n'existe pas déjà).
* Ajouter l'utilisateur courant à ce groupe.

{% highlight bash %}
sudo groupadd docker
sudo usermod -aG docker USERNAME
sudo /etc/init.d/docker restart
{% endhighlight %}

Depuis la version 0.5.3, si l'on (ou l'installeur de Docker) ajoute un group Unix appelé "docker" et qu'on lui ajoute des utilisateurs,
alors docker donnera accès en lecture/écriture sur le socket Unix au groupe docker lors du démarrage du process.

## Commandes docker sur l'hôte

Après avoir effectué la manipulation décrite précédemment on peut travailler sans root/sudo depuis l'hôte.
On évite ainsi certains désagréments :

* Des commandes docker parfois complexe

{% highlight bash %}
sudo docker rm -f $(sudo docker ps -aq)
{% endhighlight %}

devient
 
{% highlight bash %}
docker rm -f $(docker ps -aq)
{% endhighlight %}

* Le mot de passe root n'est plus demandé de manière intenpestive et on ne perd pas de temps à le retrouver !

**Attention !** Soyez bien conscient de ce que vous faites en diminuant
le niveau de privilèges nécessaire pour l'utilisation de docker.

## Utilisateur dans les container

Nous avons résolu le problème de l'utilisateur **root** sur l'hôte, mais le problème est toujours là
lorsqu'on lance des commandes/scripts directement depuis un container.

Par défaut, c'est systématiquement l'utilisateur **root** qui est utilisé.
C'est avec cet utilisateur que **TOUTES** les commandes sont lancées.
On ne rencontre ainsi jamais aucun problème en lien avec les droits utilisateurs.

Par contre, cette utilisation de **root** par défaut, pose plusieurs problèmes :

* Aucun contrôle des droits et autorisations.
* On peut accéder en root à tous les fichiers partagés via un VOLUME.
* Tous les fichiers créés depuis un container appartiennent à root.
* On lance en permanence des commandes en root alors que cela n'est pas nécessaire, voire même... pas autorisé par certain programme.

**Voyons donc comment travailler facilement sans root** !

### Un utilisateur basique dans le Dockerfile

#### Pourquoi ne pas ajouter un utilisateur "classique" dans l'image Docker construite via notre `Dockerfile` ?

{% highlight bash %}
RUN groupadd -f -g 1000 bob && \
    useradd -u 1000 -g bob bob && \
    mkdir -p /home/bob

RUN chown -R bob:bob /home/bob

{% endhighlight %}

Sous Linux, les groupes et les utilisateurs sont gérés via des nombres. Généralement le premier utilisateur classique créé aura l'id 1000.
C'est pareil pour le premier groupe. Sous Fedora/CentOS, le premier ID attribué sera 500. Ce paramétrage se trouve en fait dans le fichier
`/etc/login.defs`.

{% highlight bash %}
$ cat /etc/login.defs | grep 1000
UID_MIN			 1000
GID_MIN			 1000
{% endhighlight %}


#### Et pourquoi ne pas se connecter systématiquement avec cet utilisateur lorsqu'on accède à un container ?

{% highlight bash %}
$ docker run -it --rm -u bob mon_image_docker:v1.0 bash
bob@e1afa2726fab:/var/www$ exit
{% endhighlight %}


#### Limitations

Si vous avez un seul utilisateur sur votre machine hôte et qu'il a bien lui aussi un id et un groupe à 1000, tout se passera bien.
En effet, en matière de droits d'accès seul les `uid`, `gid`, ... sont comparés, peut importe les noms d'utilisateurs.

{% highlight bash %}
$ id
uid=1000(john) gid=1000(john) groupes=1000(john),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),108(lpadmin),124(sambashare),999(docker)
{% endhighlight %}


Que faire alors pour gérer les autres utilisateurs susceptibles de travailler avec cette image ?

* Plusieurs utilisateurs d'une même machine hôte (ids 1001, 1002,...).
* Le lancement d'un container par Jenkins (`uid=105(jenkins) gid=65534(nogroup) groups=65534(nogroup)`).


### Un utilisateur avec id et groupe identiques à l'utilisateur courant

La solution permattant de travailler dans un container docker avec les mêmes droits et privilèges
que l'utilisateur courant, réside dans le fait de créer cet utilisateur et de se connecter avec lors de chaque accès au container.

Je vous présente ci-dessous ma façon de faire à travers un `Makefile`. Cela me permet d'abstraire la compléxité de la commande à éxecuter.
Mais la solution peut être déclinée pour un fonctionnement via un script shell par exemple :

{% highlight bash %}
TARGET_USERNAME = bob
TARGET_GROUPNAME = bob
HOMEDIR = /home/$(TARGET_USERNAME)
UID = $(shell id -u)
GID = $(shell id -g)

ADD_USER_GROUP_COMMAND = \
    groupadd -f -g $(GID) $(TARGET_GROUPNAME) && \
    useradd -u $(UID) -g $(TARGET_GROUPNAME) $(TARGET_USERNAME) && \
    mkdir -p $(HOMEDIR) &&

AUTHORIZE_TARGET_USER_COMMAND = chown -R $(TARGET_USERNAME):$(TARGET_GROUPNAME) $(HOMEDIR) &&
START_AS = sudo -E -u $(TARGET_USERNAME) HOME=$(HOMEDIR)
{% endhighlight %}

Le code ci-dessus permet l'initialisation de variables afin de configurer différentes chose à la volée :

* La création d'un groupe.
* La création d'un utilisateur avec un répertoire racine (/home/bob).
* Le changement de propriétaire du répertoire racine.
* La connexion avec l'utilisateur **bob** créé.

**Très important !** L'argument -E de la commande `sudo -E ...` permet la propagation des variables d'environnements (disponibles uniquement pour root par défaut).

#### Mais comment utiliser ces différentes variables ?

Pour construire ce blog, nous travaillons avec docker, docker-compose et un Makefile. Une des cibles de notre Makefile permet la récupération
des dépendances du projet grâce à **bundler**.

{% highlight bash %}
bundle:
	@echo "Bundler"
	@docker-compose run --rm web bash -ci '\
                $(ADD_USER_GROUP_COMMAND) \
                $(AUTHORIZE_TARGET_USER_COMMAND) \
                $(START_AS) bundle install --path vendor/bundle'
{% endhighlight %}

En faisant un `make bundle`, on récupère toutes les dépendances de notre projet dans le dossier `vendor/bundle`,
et tous les fichiers comportent le bon groupe et le bon id.

**Ah oui ! Nous avons défini un volume pointant sur le
répertoire courant du projet afin d'avoir accès aux vendors depuis la machine hôte**.

**Attention !** Si vous travaillez avec **boot2docker** cela ne fonctionnera pas !
Mais vous pouvez essayer d'utiliser les variables suivantes dans le cas où vous souhaitez construire un Makefile compatible avec Docker (Linux) et boot2docker :

{% highlight bash %}
TARGET_USERNAME = root
TARGET_GROUPNAME = root
HOMEDIR = /root
ADD_USER_GROUP_COMMAND =
{% endhighlight %}

### Quelques astuces

#### Astuce 1

Si vous utilisez les variables `$(ADD_USER_GROUP_COMMAND)`, `$(AUTHORIZE_TARGET_USER_COMMAND) ` et `$(START_AS)` de la même manière lors du lancement
de différents containers, vous pouvez créer une variable supplémentaire et l'utiliser de cette façon :

{% highlight bash %}
CUSTOM_CMD = $(ADD_USER_GROUP_COMMAND) \
    $(AUTHORIZE_TARGET_USER_COMMAND) \
    $(START_AS)

bundle:
	@echo "Bundler"
	@docker-compose run --rm web bash -ci '\
                $(CUSTOM_CMD) bundle install --path vendor/bundle'
{% endhighlight %}

#### Astuce 2

Si vous souhaitez déterminer depuis un Makefile si vous êtes sous Linux ou Mac, vous pouvez utiliser ceci :

{% highlight bash %}
ifeq (Darwin, $(findstring Darwin, $(shell uname)))
  SYSTEM := OSX
else
  SYSTEM := Linux
endif

ifeq ($(SYSTEM), OSX)
    ...
else
    ...
endif
{% endhighlight %}

#### Astuce 3

Pour partager une clé SSH dans un container, vous pouvez utiliser ces variables et VOLUMEs :

{% highlight bash %}
HOST_KNOWN_HOSTS ?= ~/.ssh/known_hosts
HOST_IDENTITY ?= ~/.ssh/id_rsa

bundle:
	@echo "Bundler"
	@docker-compose run --rm \
            -v $(HOST_KNOWN_HOSTS):/var/tmp/host_known_hosts \
            -v $(HOST_IDENTITY):/var/tmp/host_id \
            web bash -ci '\
                $(CUSTOM_CMD) bundle install --path vendor/bundle'
{% endhighlight %}

**Attention !** Cela suppose d'avoir un mécanisme permettant de copier les fichiers `/var/tmp/known_hosts` et `/var/tmp/id`
au bon endroit lors du lancement du container  :

{% highlight bash %}
CONFIG_SSH_COMMAND = \
  mkdir -p $(HOMEDIR)/.ssh && \
  test -e /var/tmp/host_id && cp /var/tmp/host_id $(HOMEDIR)/.ssh/id_rsa ; \
  test -e /var/tmp/host_known_hosts && cp /var/tmp/host_known_hosts $(HOMEDIR)/.ssh/known_hosts ; \
  test -e $(HOMEDIR)/.ssh/id_rsa && chmod 600 $(HOMEDIR)/.ssh/id_rsa ;
  
...
  
CUSTOM_CMD = $(ADD_USER_GROUP_COMMAND) \
    $(CONFIG_SSH_COMMAND) \
    $(AUTHORIZE_TARGET_USER_COMMAND) \
    $(START_AS)
{% endhighlight %}


