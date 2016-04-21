---
layout: post
title: Déployer un dashboard de monitoring temps réel via Docker
author: mathieu_molimard
excerpt: "Avec Docker, tester de nouveaux logiciels est extrêmement facile, nous allons tester aujourd'hui un outil de monitoring temps reel"
tags: [docker, monitoring, real-time, linux]
comments: true
image:
  feature: headers/docker.jpg
---

Yannick, notre lead chéri, a vu passer un outil très interessant pour le monitoring des serveurs. Il s'agit de netdata, clonable depuis : [https://github.com/firehol/netdata.git](https://github.com/firehol/netdata.git)

Je ne vous parlerai pas de la myriade d'options disponibles, tout est extremement bien détaillé sur le wiki du projet ([https://github.com/firehol/netdata/wiki](https://github.com/firehol/netdata/wiki))

Nous l'avons déployé sur nos serveurs en utilisant l'image docker récupérable sur le hub docker : [https://hub.docker.com/r/titpetric/netdata/](https://hub.docker.com/r/titpetric/netdata/)

Pour lancer le dashboard, une seule commande suffit :

{% highlight bash %}

docker run -d --cap-add SYS_PTRACE --name netdata -v /proc:/host/proc:ro -v /sys:/host/sys:ro -p 19999:19999 titpetric/netdata

{% endhighlight %}


<img src="/images/2016-04-20/netdata.png">

Et vous vous retrouvez avec un joli dashboard temps réel, une heure de rétention... Parfait pour faire de joli mur de monitoring... Bientôt, très bientôt..
