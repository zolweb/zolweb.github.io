---
layout: post
title: Compatibilité des noyaux grsc installés par OVH avec docker
author: mathieu_molimard
excerpt: "Docker utilise des fonctionnalités avancées des kernels... Il faut faire attention à ce que les noyaux les proposent..."
tags: [docker, ovh, grsc, kernel; soyoustart]
comments: true
image:
  feature: headers/docker.jpg
---

Nous utilisons Docker pour quelques sites en production, cela nous permet de déployer nos projets extrèmement rapidement tout en étant complétement iso entre nos devs, notre préprod et notre serveur de production. Nous avons choisi d'héberger nos serveurs de préproduction et et de production chez Online et puisqu'il ne faut pas rester toujours dans la même cremerie (et aussi pour suivre les conseils de mes précieux collègues), nous avons pris un serveur chez SoYouStart (OVH).

Et la début des ennuis... Problèmes étranges, timeout, lenteur... Quelques heures de réflexion plus tard, je me suis souvenu que les noyaux livrés sur les distro de base chez OVH sont des noyaux implémentant les modifications grsecurity. Pour rappel, ces modifications permettent d'augmenter la sécurité (voir <a href='https://fr.wikipedia.org/wiki/Grsecurity' target='_blank'>https://fr.wikipedia.org/wiki/Grsecurity</a>). Malheusemenent, ces noyaux sont pas spécialement compatibles avec Docker, encore moins lorsque l'on fait du docker dans docker, ce que nous faisons avec notre serveur Jenkins.

Heureusement, il est très facile avec Linux de changer de noyaux, pour cela, il suffit d'installer le dernier noyau livré de base sur les repository backport de Jessie :

* Vérifier dans un premier temps, que les repos backport sont bien activés dans le fichier /etc/apt/sources

{% highlight bash %}
# jessie-backports, previously on backports.debian.org
deb http://debian.mirrors.ovh.net/debian/ jessie-backports main
deb-src http://debian.mirrors.ovh.net/debian/ jessie-backports main
{% endhighlight %}

* Mettre à jour ensuite la liste des paquets, puis installer le nouveau kernel

{% highlight bash %}
apt-get update
apt-get install linux-image-4.2.0-0.bpo.1-amd64
{% endhighlight %}

* Il faut enfin préciser à grub que nous allons utiliser ce noyau et pas le noyau livré de base avec la distro pour booter notre serveur, pour cela, il faut regarder quel est l'index de notre noyau en faisaint un cat du fichier /boot/grub/grub.cfg, attention, il faut compter à partir de 0.

Dans notre cas, le noyau est en position 2, il faut le spécifier dans le fichier /etc/default/grub en modifiant l'entrée :

{% highlight bash %}
GRUB_DEFAULT=2
{% endhighlight %}

puis regénérer le fichier /boot/grub/grub.cfg en executant la commande :

{% highlight bash %}
update-grub
{% endhighlight %}

Vous pouvez rebooter, tout devrait BEAUCOUP mieux fonctionner ;)
