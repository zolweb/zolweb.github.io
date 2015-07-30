---
layout: post
title: Docker sans utilisateur root sur l'hôte et dans les containers
author: yannick_pereirareis
excerpt: "Lorsqu'on travaille avec Docker, par défaut tout se fait en root : installation, lancement de commandes depuis l'hôte et lancement de commandes dans les containers. Mais ce comportement peut être modifié grâce à quelques configurations et lignes de commandes."
tags: [docker, user, utilisateur, root, container]
comments: false
image:
  feature: headers/remotework.jpg
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

Mais voilà.... comme vous le voyez il est nécessaire d'avoir les privilèges **root** et au quotidien
cela est vraiment très pénalisant, surtout en mode développement. Mais il existe une solution : 

* Créer un groupe **docker**.
* Ajouter l'utilisateur à ce groupe.

{% highlight bash %}
sudo groupadd docker
sudo usermod -aG docker USERNAME
sudo /etc/init.d/docker restart
{% endhighlight %}

Depuis la version 0.5.3, si l'on (ou l'installeur de Docker) ajoute un group Unix appelé "docker" et que lui ajoute des utilisateurs,
alors docker rendra

Starting in version 0.5.3, if you (or your Docker installer) create a Unix group called docker and add users to it,
then the docker daemon will make the ownership of the Unix socket read/writable by the docker group when the daemon starts.

## Commandes docker sur l'hôte

En effectuant la manipulation décrite précédemment on peut désormais travailler sans root/sudo depuis l'hôte.
On évite ainsi des désagréments génants :

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
le niveau de privilèges nécessaire pour le l'utilisateur de docker.

## Utilisateur dans les container

Nous avons résolu le problème de l'utilisateur **root** sur l'hôte, mais le problème est toujours là
lorsqu'on lance des commandes/scripts directement depuis un container.

Par défaut, c'est toujours l'utilisateur **root** qui est utilisé.
C'est avec cet utilisateur que **TOUTES** les commandes sont lancées.
On ne rencontre ainsi jamais aucun problème en lien avec les droits utilisateur.

Par contre, cette utilisation de **root** par défaut pose bien des problèmes :

* Aucun contrôle des droits et autorisations.
* Au sein d'un container





* ENV /home
* useradd 1000 -> pbl jenkins
* useradd à la vollée !!! 