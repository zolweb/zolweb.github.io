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
Nous sommes passés à Vagrant mi 2014... rendant obsoléte notre ancienne plateforme de préproduction... A l'époque, une plateforme hébergeant tous les projets sur un seul et même apache avec une seule et même base de données... Nous avons donc imaginé une nouvelle plateforme qui nous permet de déployait les box sur le serveur derrière un proxy... Le tout presque automatiquement.

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


