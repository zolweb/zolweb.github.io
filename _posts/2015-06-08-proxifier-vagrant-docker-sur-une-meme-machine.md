---
layout: post
title: Proxifier efficacement des machines virtuelles et des containers docker tournant sur la même machine physique
author: mathieu_molimard
excerpt: "Proxifier efficacement des machines virtuelles et des containers docker tournant sur la même machine physique"
tags: [docker, vagrant, nginx]
modified: 2015-06-08
comments: false
image:
  feature: proxifier-vagrant-docker-sur-une-meme-machine.jpg
---

Nous avons été confronté à la problématique de la configuration de Nginx (en mode serveur web et reverse proxy), de Vagrant et de Docker
sur notre serveur de **pré-production** que nous utilisons afin de réaliser des CQTs (cellule qualité temporaire) et permettre à nos clients
de faire la "recette" des derniers développements effectués par les équipes projets.

A l'origine, notre plateforme de pré-production hébergeait tous nos projets sur :

* un seul et même serveur physique...
* un seul et même serveur web Apache...
* une seule et même base de données...

<img src="/images/docker-vagrant-1.svg">

## Vagrant

Nous avons ensuite décidé, mi 2014, de mettre en oeuvre [VirtualBox](https://www.virtualbox.org/) et [Vagrant](https://www.vagrantup.com/)
pour tous nos projets, en **dev** comme en **preprod**. Nous avons alors imaginé une architecture nous permettant de déployer les projets
en pré-production grâce à Vagrant et à des VMs tournant derrière un reverse proxy Nginx.
Grâce à un script ce procces de déploiement était quasi automatique :

* Clonage du repository sur le serveur de preprod via git.
* Création d'un Virtual Host pour le reverse proxy Nginx.
* Création d'un fichier `.htpasswd` pour l'authentification.
* Redémarrage du reverse proxy.
* Lancement du projet en preprod via la commande `vagrant up`

Ce process permettait de passer d'un environnement de dev à l'environnement de preprod très simplement. La plupart du temps nous chargions des confs de dev sur la préprod.
La partie **consommant le plus de temps** étant bien entendu le provisioning de la VM.
La partie **la plus comliquée** étant la gestion de la communication entre le reverse proxy et les machines virtuelles.

Nous avons résolu ce problème grâce à un plugin Vagrant très pratique, ([vagrant-hostmanager](https://github.com/smdahlen/vagrant-hostmanager))
permettant de mettre à jour le fichier `hosts` de l’hôte automatiquement lors du démarrage d'un VM, en ajoutant seulement deux lignes de configuration dans le `Vagrantfile`:

{% highlight ruby %}
config.hostmanager.enabled = true
config.hostmanager.manage_host = true
{% endhighlight %}

<img src="/images/docker-vagrant-2.svg">

## Docker

Avec l'arrivée de **Docker**, nous avons décidé de migrer vers cet outil pour tous nos nouveaux projets,
chaque projet fonctionnant grâce à un ensemble de plusieurs containers Docker (Nginx, MySQL, Composer, Selenium,...).
Afin d'orchestrer chaque projet, nous avons utilisé [fig](http://www.fig.sh/) puis [docker compose](https://docs.docker.com/compose/).

Nous nous sommes retrouvés avec des VMs et des containers Docker à déployer en preprod et cela ne pose aucun problème.
Par contre, cela suppose bien entendu de faire en sorte que le reverse proxy redirige correctement vers les VMs ou vers les containers Docker.
Pour chaque application fonctionnant avec Docker il nous a fallu configurer une redirection et des entrées dans le fichier `hosts` de l'hôte.

Le plugin **vagrant-hostmanager** ne fonctionnant que pour Vagrant (évidemment),
nous avons créé un script shell permettant de modifer automatiquement le fichier `host` de l'hôte pour les containers docker :


{% highlight bash %}
#!/bin/sh
set -e

IP=`sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' ${1}`
HOST=$2

[ -z "$HOST" ] && exit 1;

sudo sed -i "s/.*\s${HOST}$/${IP} ${HOST}/" /etc/hosts

grep -P "\s${HOST}$" /etc/hosts > /dev/null || sudo -- sh -c "echo \"${IP} ${HOST}\" >> /etc/hosts"
grep -P "^${IP} ${HOST}$" /etc/hosts > /dev/null

if [ $? -eq 0 ]; then
    echo "Set host: ${IP} ${HOST}"
else
    echo "Fail to update the host file with: ${IP} ${HOST}"
fi
{% endhighlight %}

Nous avons rencontré deux problèmes avec ce script :

* Lors du redemarrage des containers, nous étions systématiquement obligés de redémarrer manuellement le proxy pour qu’il prenne en compte les nouvelles IP des containers. On utilisait bien des noms de domaines dans les vhosts de nginx, mais le fichier `hosts` de la machine n'était pas pris en compte sans que l'on redemarre le service.
* Le script custom n'était pas compatble avec la commande `sed` de mac os.


### Reverse proxy nginx dans un container Docker

Le script de modification du fichier `hosts` de l'hôte étant très lourd a gérer, à maintenir et à utiliser en dev et sous mac,
nous avons cherché et trouvé une bien meilleure solution :

>> le projet **[https://github.com/jwilder/nginx-proxy](https://github.com/jwilder/nginx-proxy)**

Son utilisation est extrèmement simple, il suffit de lancer un container avec la commande :

{% highlight bash %}
docker run -d -p 8080:80 \
	   -v /var/run/docker.sock:/tmp/docker.sock jwilder/nginx-proxy
{% endhighlight %}

Une fois ce container lancé, nous disposons d'un reverse proxy nginx automatique vers tous nos containers Docker applicatifs.

Il va détecter automatiquement les containers qui nécessitent d’avoir un vhost sur le reverse proxy, c'est magique.

Il suffit d’injecter dans les containers applicatifs (via le fichier docker-composer.yml dans notre cas) une variable d’environnement qui correspondra
au ServerName / ServerAlias associé container Web.

{% highlight bash %}
web:
    build: docker/web
    working_dir: /var/www
    environment:
       - VIRTUAL_HOST=www.zol.fr,zol.fr
{% endhighlight %}


Mais évidemment, tout n'est pas si facile...
Impossible de faire tourner en même temps le nginx que nous utilisions pour l’ensemble des projets (vagrant et docker),
**ET** ce fameux container qui s’auto-configure... En effet, on ne peut pas lancer deux services sur un même port pour une même IP.

Face à ça, nous avons imaginé plusieurs solutions :

* Faire tourner le container et le serveur nginx sur des ports différents...
Le soucis étant que nos clients auraient eu des urls en *http://domain:81* par exemple, pas très pratique...

* Obtenir une nouvelle IP auprès de notre hébergeur et utiliser une IP pour le nouveau proxy et une pour l'ancien.
Le soucis étant que pour faciliter la procédure de mise en pré-production, tous les sous-domaines de .preprod.zol.fr pointent vers la même IP.
Il aurait donc fallu soit avoir deux sous domaines *.preprod.zol.fr et *.preprod-new.zol.fr par exemple.
Soit enregistrer manuellement les entrées DNS chez notre hoster. Pénible !

* Utiliser un proxy devant les proxy :)


Nous avons logiquement décidé d’utiliser la troisième solution
et nous avons pour cela mis en place la stack suivante en utilisant [Varnish](https://www.varnish-cache.org/) comme reverse proxy principal :

<img src="/images/docker-vagrant-3.svg">

Tous les nouveaux projets de ZOL étant développés avec docker, nous avons donc deux backend...
Un premier backend **nginxDocker** qui redirige les requêtes HTTP vers le container nginx,
et un second, **nginxHost**, pour rediriger les requêtes HTTP sur ce qui est devenu l’ancien backend, à savoir le serveur nginx installé sur la machine.

Le fichier de configuration de varnish ressemble à :

{% highlight bash %}
backend nginxHost {
        .host = "127.0.0.1";
        .port = "8081";
        .first_byte_timeout = 600s;
        .between_bytes_timeout = 600s;
}

backend nginxDocker {
        .host = "127.0.0.1";
        .port = "8080";
        .first_byte_timeout = 600s;
        .between_bytes_timeout = 600s;
}


sub vcl_recv {
  if (req.http.host ~ "^atlive" || req.http.host  ~ "^prestadom" || req.http.host  ~ "^recrutemoi"  || req.http.host  ~ "^geoffre-front" ) {
              set req.backend = nginxHost;
  } else {
            set req.backend = nginxDocker;
        }
}
{% endhighlight %}

Vous l'aurez deviné, il faut faire tourner les différents reverse proxy sur des ports différents :

* **Varnish** sur le port **80**
* **Reverse proxy Docker** sur le port **8080**
* **Reverse proxy sur l'hôte** sur le port **8081**

La configuration de Varnish permet de rediriger correctement vers Docker ou Vagrant.

>> Nous avons utilisé Varnish comme point d'entrée sur notre serveur.
>> Nous aurions pu utiliser n'importe quel autre reverse proxy.

Voilà, comment nous avons fait évoluer notre plate forme de pré-production au fil du temps,
avec les différentes contraintes liés à l'utilisation de vagrant et docker sur une même machine.
