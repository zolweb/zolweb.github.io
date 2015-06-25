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

[SCHEMA ICI]

## Vagrant

Nous avons ensuite décidé, mi 2014, de mettre en oeuvre [VirtualBox](https://www.virtualbox.org/) et [Vagrant](https://www.vagrantup.com/)
pour tous nos projets, en **dev** comme en **preprod**. Nous avons alors imaginé une architecture nous permettant de déployer les projets
en pré-production grâce à Vagrant et à des VMs tournant derrière un reverse proxy Nginx.
Grâce à quelques scripts ce procces de déploiement était quasi automatique :

* Création (par un job Jenkins) d'une box provisionée (PHP, Apache, MySQL,....) avec le projet en mode "prod", à partir des derniers développements effectués.
* Clonage du repository sur le serveur de preprod via git.
* Lancement du projet en preprod via la commande `vagrant up prod` permettant de charger la box précédemment construite par jenkins.
* Création d'un Virtual Host pour le reverse proxy Nginx.
* Création d'un fichier `.htpasswd` pour l'authentification.
* Redémarrage du reverse proxy.

Ce process permettait de passer d'un environnement de dev à l'environnement de preprod simplement grâce à des provisionning dédiés configurés dans le `Vagrantfile`.
La partie **consommant le plus de temps** étant bien entendu le provisioning de la VM.
La partie **la plus comliquée** étant la gestion de la communication entre le reverse proxy et les machines virtuelles.

Nous avons résolu ce problème grâce à un plugin Vagrant très pratique, ([vagrant-hostmanager](https://github.com/smdahlen/vagrant-hostmanager))
permettant de mettre à jour le fichier `hosts` de l’hôte automatiquement lors du démarrage d'un VM, en ajoutant seulement deux lignes de configuration dans le `Vagrantfile`:

{% highlight ruby %}
config.hostmanager.enabled = true
config.hostmanager.manage_host = true
{% endhighlight %}

[SCHEMA ICI]

## Docker

Avec l'arrivée de **Docker**, nous avons décidé de migrer vers cet outils pour tous nos nouveaux projets,
chaque projet fonctionnant grâce à un ensemble de plusieurs containers Docker (Nginx, MySql, Composer, Selenium,...).
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


[SCHEMA ICI]

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
impossible de faire tourner en même temps le nginx que nous utilisions pour l’ensemble des projets (vagrant et docker),
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

<img src="/images/docker-vagrant.svg">

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

Vous aurez remarqué, qu'il faut faire tourner les différents reverse proxy sur des ports différents :

* **Varnish** sur le port **80**
* **Revers proxy Docker** sur le port **8080**
* **Revers proxy sur l'hôte** sur le port **8081**

La configuration de Varnish permet de rediriger correctement vers Docker ou Vagrant.

>> Nous avons utilisé Varnish comme point d'entrée sur notre serveur.
>> Nous aurions pu utiliser n'importe quel autre reverse proxy, un autre nginx par exemple.

Voilà, comment nous avons fait évoluer notre plate forme de pré-production au fil du temps,
avec les différentes contraintes liés à l'utilisation de vagrant et docker sur une même machine.

==========================================

Nous sommes passés à Vagrant mi 2014... rendant obsoléte notre ancienne plateforme de préproduction...
A l'époque, une plateforme hébergeant tous les projets sur un seul et même apache avec une seule et même base de données...

Nous avons donc imaginé une nouvelle plateforme qui nous permet de déployait les box sur le serveur derrière un proxy...
Le tout presque automatiquement.

Pour faire cela, nous avions imaginé un process assez simple mais franchement pratique :

* clonage du repository
* création du vhost pour le reverse proxy
* création automatique d’un fichier htpasswd
* redémarrage du reverse proxy

Le tout étant scripté... On pouvait facilement passer nos projets d'un environnement de dev vers un environnement preprod en ne modifiant rien de la configuration (Vagrantfile), le plus long était clairement le provisionning de la machine.

La partie la plus compliquée étant la communication entre le proxy et les machines virtuelles, nous l'avions délégué à un plugin pour vagrant ([https://github.com/smdahlen/vagrant-hostmanager](https://github.com/smdahlen/vagrant-hostmanager)) permettant de mettre à jour le fichier host de l’hôte en ajoutant seulement deux lignes dans le fichier Vagrantfile.

{% highlight ruby %}
config.hostmanager.enabled = true
config.hostmanager.manage_host = true
{% endhighlight %}


Mais mettre à jour les fichiers hosts de la machine n’est pas forcemment une bonne idée en soit...  Pas évident non plus, surtout avec Docker où on utilisait un script custom (incompatible avec mac os).

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


Nous rencontrions deux problèmes avec ce script... Le premier était lors du redemarrage des containers, chaque fois, nous étions obligé de redémarrer manuellement le proxy pour qu’il prenne en compte la nouvelle IP du container... On utilisait bien des noms de domaines dans les vhosts de nginx mais le fichier host de la machine n'était pas pris en compte sans que l'on redemarre le service. Le second concernait mac os, le script custom étant incompatble avec la commande sed de mac os.

Nous avons trouvé un container qui permettait de faire exactement tout ça, à savoir effectuer le reverse proxy sans avoir à modifier le fichiers host de la machine hôte.

Ce reverse proxy est basé sur un nginx dans un container docker evidemment ;).

Pour l’utiliser, extrêmement simple, il suffit de lancer le container jwilder/nginx-proxy avec la commande :


{% highlight bash %}
docker run -d -p 8080:80 -v /etc/nginx/passwords:/etc/nginx/htpasswd -v \
	   /var/run/docker.sock:/tmp/docker.sock jwilder/nginx-proxy
{% endhighlight %}

Une fois ce container lancé, il va détecter automatiquement les containers qui nécessitent d’avoir un vhost sur le proxy. C’est magique, il suffit d’injecter dans le container (via le fichier docker-composer.yml) une variable d’environnement qui correspondra au ServerName / ServerAlias associé container Web.

{% highlight bash %}
web:
    build: docker/web
    working_dir: /var/www
    hostname: zol
    volumes:
        - ".:/var/www"
        - "./var/logs/web:/var/log/apache2"
    links:
        - db
    environment:
       - VIRTUAL_HOST=www.zol.fr,zol.fr
{% endhighlight %}

Mais évidemment, tout n'est pas si facile... impossible de faire tourner en même temps le nginx que nous utilisions pour l’ensemble des projets (vagrant et docker) et ce fameux container qui s’autoconfigure... (Je rappelle qu'on ne peut pas lancer deux services sur le même port et la même IP).

Face à ça, nous avons imaginé plusieurs solutions :

* faire tourner le container ou le serveur nginx sur des ports différents... Le soucis c’est que nos clients auraient eu parfois des urls en :81, pas très pratique...

* obtenir une nouvelle IP auprès de notre hébergeur et utiliser une IP pour le nouveau proxy et une pour l'ancien. Le soucis c’est que pour faciliter la procédure de mise en pré-production, tous les sous-domaines de .preprod.zol.fr pointent vers la même IP. Il faudrait donc soit avoir deux sous domaines *.preprod.zol.fr et *.preprod-new.zol.fr par exemple. Soit enregistrer manuellement les entrées DNS chez notre hoster. Pénible.

* Utiliser un proxy devant les proxy :)

Nous avons logiquement décidé d’utiliser la troisième solution et nous avons pour cela mis en place la stack suivante :

<img src="/images/docker-vagrant.svg">

Tous les nouveaux projets de ZOL sont développés avec docker, nous avons donc deux backend... Un backend default qui redirige les requêtes HTTP vers le container nginx et on a donc configuré Varnish pour rediriger les requêtes http sur ce qui est devenu l’ancien backend à savoir le serveur nginx installé sur la machine.

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
