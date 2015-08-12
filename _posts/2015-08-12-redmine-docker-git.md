---
layout: post
title: Brancher les dépots git dans un redmine tournant sous docker 
author: mathieu_molimard
excerpt: "Redmine est depuis très longtemps notre outil de ticket, depuis quelques temps, nous le faisons tourner dans docker ce qui nous permet d'avoir facilement une version à jour, mais nous avions perdu la possibilité de rattacher les repo git au projet... Après quelques recherches, voilà comme nous avons contourné ce problème."
tags: [mathieu molimard, docker, redmine, git]
comments: true
image:
  feature: headers/docker.jpg
---

## Redmine, notre outil de gestion de projet

Nous utilisons redmine depuis très longtemps comme interface avec nos clients, saisir des tickets, les timer, rattacher des commits sur ces tâches, saisir nos heures... Redmine a toujours été au coeur de l'organisation de ZOL. La version de notre première instance de redmine est restée figée à 1.1.3 stable : plugins incompatibles, version de ruby obsoléte... A chaque nouvelle version de redmine se posait le même dilemne : upgrader ou garder notre version fonctionnelle, plusieurs expériences malheureuses plus tard ;) nous avions décidé de rester en version 1.1.3, mais ça, c'était avant.

### Une version dockerisée

sameersbn met à disposition une version dockerisée régulièrement mise à jour <a href='https://github.com/sameersbn/docker-redmine/' target='_blank'>docker-redmine</a>, nous n'avons plus à nous soucier des mises à jour de version de ruby, il suffit de modifier la version dans le fichier docker-compose.yml  
 
{% highlight bash %}
redmine:
  image: sameersbn/redmine:3.0.3
  hostname: redmine
  domainname: redmine.dev
  links:
    - postgresql:postgresql
...
{% endhighlight %}


### Limite, solution... 

Sameersbn met à disposition un système permettant d'installer des plugins, il suffit de décompresser les plugins redmine dans le dossier /data/plugins, lors du démarrage du container les plugins seront installés, jusque là aucun soucis, mais comment faire pour utiliser nos dépôts git. Je rappelle que pour linker des id de commit avec des tasks redmine, il faut que les dépôts bare soient accessibles depuis les sources de redmine. Rien n'est prévu dans l'image de sameersbn pour faire cela.

Pour contourner ce problème, nous avons créé un nouveau répertoire, tiré les repos bare qui nous interessent avec la commande : 

{% highlight bash %}
git clone --bare git@bitbucket.org:zol/fakeproject.git fakeproject
{% endhighlight %}

Nous avons ensuite monté ce répertoire comme un volume dans l'image docker-redmine en modifiant le fichier docker-compose.yml

{% highlight bash %}
redmine:
  image: sameersbn/redmine:3.0.3
  hostname: redmine
  domainname: redmine.dev
  links:
    - postgresql:postgresql
...
      volumes:
    - "/srv/projects/zol-connect/gitrepositories:/home/gitrepositories"
{% endhighlight %}

Nous pouvons à ce stade spécifier dans les settings du projet, 

<img src="/images/2015-08/redmine-git-settings.png">

Pour associer, un commit à une task, il suffit de spécifier refs #id dans le message, les commits apparaitront directement dans la task. **Attention, il ne faut spécifier qu'un seul id de task par commit** même si techniquement rien n'empêche d'en spécifier plusieurs. 

Il faut maintenant mettre à jour nos repos bare régulièrement, pour cela nous avons utilisé une des fonctionnalités de l'image docker-redmine qui permet d'ajouter des cron au démarrage du container. Nous avons créé un fichier init dans /data/plugins/

{% highlight bash %}
## Recurring Tasks Configuration

# get the list existing cron jobs for the redmine user
crontab -u redmine -l 2>/dev/null >/tmp/cron.redmine

cd /home/gitrepositories
for folder in *; do 
echo "* * * * *  cd /home/gitrepositories/${folder} && git fetch origin +refs/heads/*:refs/heads/* && git reset --soft" >>/tmp/cron.redmine;
done;
echo "* * * * *  cd /home/redmine/redmine && ./bin/rails runner 'Repository.fetch_changesets' -e production >> log/cron_rake.log 2>&1" >>/tmp/cron.redmine;

crontab -u redmine /tmp/cron.redmine 2>/dev/null


# remove the temporary file
rm -rf /tmp/cron.redmine

## End of Recurring Tasks Configuration

{% endhighlight %}

A chaque démarrage du container, on ajoutera donc un cron qui va mettre à jour les repo présents dans /home/gitrepositories/

Une dernière subtilité... Puisque les repo vont être mis à jour depuis le container redmine et que nous utilisons la clé de deploiement de l'utilisateur prod pour mettre à jour les projets, il faut ajouter les clés de l'utilisateur prod dans le dossier data/dotfiles/.ssh/
A la fois la clé publique et privée, mais aussi le fichier known_hosts, sans quoi il y aura la question : 

{% highlight bash %}
The authenticity of host '111.222.333.444 (111.222.333.444)' can't be established.
RSA key fingerprint is f3:cf:58:ae:71:0b:c8:04:6f:34:a3:b2:e4:1e:0c:8b.
Are you sure you want to continue connecting (yes/no)? 

{% endhighlight %}

C'est prêt, vous pouvez utiliser les repos git avec docker tournant sous redmine.