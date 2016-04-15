---
layout: post
title: Comment mettre en place des tests Behat utilisant le driver Selenium sous Docker ?
author: christophe_hautenne
excerpt: "Les tests fonctionnels couvrent l'experience utilisateur, or le javascript est de plus en plus au coeur des sites web. Qu'en est-il des tests js, qui plus est sous docker ?"
tags: [docker; selenium, behat, mink]
comments: true
image:
  feature: headers/behat.jpg
---

# Introduction

Pour les impatients ou les connaisseurs, si vous savez déjà tout (du moins pour notre sujet du jour), vous pouvez d'ores et déjà passer à la partie qui va vous interesser : [Configuration](#configuration)

D'une part, c'est un fait, le développement de tests est tout aussi important que le développement de la fonctionnalité elle même. Dans le monde du web et plus particulièrement le monde du PHP, Behat fait parti des incontournables, au même titre que PHPUnit, Atoum ..

D'autre part, les sites webs offrant de plus en plus de fonctionnalités et notamment grâce au javascript, il est normal que les tests doivent suivrent... Il est difficile d'imaginer une suite de tests efficace qui zapperait toute la partie interaction "directe" (comprenez sans rechargement de page) !

Behat utilise des "drivers" pour pouvoir se connecter à des émulateurs de browsers, headless ou non, avec chacun leurs avantages et inconvénients. Qui dit drivers dit API pour chacun d'entre eux, donc développement spécifique. Pour faciliter la vie des développeurs, il existe une extension développée pour Behat, Mink (pour vous faire une idée rapide => [Mink at a glance](http://mink.behat.org/en/latest/at-a-glance.html)). Elle permet de pouvoir changer de driver sans avoir à changer le code.

Pour des tests "classiques" et très simple à mettre en place, j'utilise Symfony2Extension, qui permet de faire des requêtes, tester des codes HTTP (200, 404, 403 ...), naviguer entre des pages ... mais pas d'interpréter du javascript. Donc pas d'ajax, pas d'animation, pas de script, rien.

La documentation de Behat est plutôt explicite sur ce point, il suffit de choisir un driver différent pour les tests JS. En théorie.
Oui parcequ'en pratique cela implique pour les tests JS d'avoir un navigateur (headless ou non, c'est à dire possibilité de voir le comportement en live) qui se lance avec la suite de tests Behat, et alors là c'est la débandade entre les connexions, le debug, le temps d'execution (lancer un navigateur et émuler une réponse HTTP sont deux choses différentes) ...

Si vous avez lu d'autres articles de ce blog, vous aurez compris qu'en plus de cette configuration, il faut prendre en compte que nous travaillons avec Docker !

Pour faire simple, j'ai eu pour un projet à mettre en place des tests JS. Ayant déjà des tests Behat et sachant qu'il existait des drivers permettant de faire ce que je voulais, c'est tout naturellement que je me suis tourné vers Selenium et son driver correspondant pour Behat.
J'ai choisis Selenium pour plusieurs raisons, notamment des images officielles docker dont nous allons nous servir par la suite.
Vous pourrez également retrouver un [comparatif des fonctionnalités d'autres drivers sur la documentation de Mink](http://mink.behat.org/en/latest/guides/drivers.html)

Venons en au coeur du sujet : j'ai trouvé TRES PEU de documentation sur comment utiliser Docker, Behat et Selenium ensemble. Il m'a fallu parfois deviner, expérimenter, essayer, avancer à taton pour en arriver au résultat final tant attendu. C'est pourquoi aujourd'hui je vous livre le fruit de mon travail, en esperant que je ferais gagner du temps de recherche à certains d'entre vous !

# Configuration

## Ressources et prérequis

Pour ce "tuto" et ces tuyaux, je m'appuie sur un projet de test appelé FFT - Selenium (vous verrez peut être des noms s'y reportant dans le code). Ce projet contient une page web avec un formulaire géré en javascript pour des besoins d'exemple.

Pour la suite, je pars du principe où vous avez des notions sur Docker (docker compose notamment) Behat et bien sûr Selenium.

Imaginons votre projet configuré de cette façon (certaines informations ont été volontairement retirées, n'ayant aucun intérêt pour l'exemple) :

behat.yml :
{% highlight yaml %}
default:
    suites:
        web:
            type: symfony_bundle
            bundle: AppBundle
            paths:
                - "/src/AppBundle/Tests/Scenarios"
            contexts:
                - Behat\MinkExtension\Context\MinkContext
                
    extensions:
        Behat\Symfony2Extension: ~
        Behat\MinkExtension:
            base_url: "http://fft-selenium.dev.zol.fr/app_dev.php"
            sessions:
                default_session:
                    symfony2: ~
{% endhighlight %}

composer.json :
{% highlight json %}
"require-dev": {
    "sensio/generator-bundle": "~3.0",
    "symfony/phpunit-bridge": "~2.7",
    "behat/behat": "~3.0",
    "behat/mink": "~1.7",
    "behat/mink-extension": "~2.1",
    "behat/mink-browserkit-driver": "~1.3",
    "behat/symfony2-extension": "~2.1"
}
{% endhighlight %}

docker-compose.yml (le build docker/web utilise l'image docker ubuntu:14.04.3 plus PHP et nginx) :
{% highlight yaml %}
web:
    build: docker/web
    working_dir: /var/www
    domainname: fft-selenium.dev.zol.fr
    environment:
        VIRTUAL_HOST: fft-selenium.dev.zol.fr
{% endhighlight %}

Et pour le plaisir une feature pour behat :
{% highlight gherkin %}
Feature: Check page response
    In order to navigate
    As an user
    I need to go on every page I want

    Scenario: Going on homepage
        When I go to "/"
        Then the response status code should be 200
{% endhighlight %}

## Objectif

Le but ici est d'arriver à lancer des tests Behat sur du javascript, à l'aide d'un serveur Selenium, l'idéal étant de pouvoir voir en live les tests s'executer. Le tout bien sûr à l'aide de Docker.

## Commençons !

La première chose à faire, ce sont les containers Selenium. Comme promis, nous allons faire tourner tout ça sous Docker, or il existe sur le docker hub tout plein d'images qui vont vous servir suivant votre cas.

#### Rappel du fonctionnement de Selenium

Selenium fonctionne sur un principe de hub/noeud. Un hub est un "point central" auquel vont se connecter les noeuds, chacun représentant un browser spécifique, un device ... Le but est de lancer les tests sur différents navigateurs, soit différents noeuds, pour s'assurer du bon fonctionnement de l'application pour un panel de terminaux. On utilise pour le hub comme pour le noeud un même fichier .jar lancé sur une machine avec des options lui indiquant son rôle. Dans le cas du noeud, on passe des paramètres supplémentaires concernant les informtions requises pour se connecter au hub.

![Schema Selenium](/images/2016-04-06/test-automation-with-selenium.jpg "Schema Selenium")
Crédits: [BioDesignAutomation](http://biodesignautomation.org/category/setting-up-a-keyword-driven/)

#### Choix des images

Il existe un repo GitHub (lien vers SeleniumHQ ici) contenant des images dockers pour Selenium qui vont nous interesser. Deux façons de procéder sont possibles : soit on utilise deux images, une pour le hub et une pour le noeud, soit une seul image "standalone" qui contient à la fois le hub et le noeud.

Pour ma part et pour l'exemple, j'utiliserai 3 images :

- selenium/hub
- selenium/node-chrome-debug
- selenium/node-firefox-debug

Je préfère la version "découplée" pour une simple raison : si demain nous avons besoin d'ajouter le navigateur Opera par exemple, il suffit de monter une image docker avec le fameux .jar pour Selenium et le driver Opera qui correspond. Restera plus qu'à se connecter au hub :)

Les images chrome et firefox debug ont la particularité d'embarquer un serveur VNC prêt à l'emploi, et c'est de cette façon que nous pourrons voir en live les tests s'executer.

#### Ajout des images dans le docker-compose.yml

{% highlight yaml %}
web:
    build: docker/web
    working_dir: /var/www
    domainname: fft-selenium.dev.zol.fr
    environment:
        VIRTUAL_HOST: fft-selenium.dev.zol.fr

hubtesting:
    image: selenium/hub:2.52.0
    ports:
        - 4444:4444

chrometesting:
    image: selenium/node-chrome-debug:2.48.2
    ports:
        # Port is used for VNC only
        - 5900:5900
    links:
        - hubtesting:hub

firefoxtesting:
    image: selenium/node-firefox-debug:2.48.2
    ports:
        # Port is used for VNC only
        - 5901:5900
    links:
        - hubtesting:hub

{% endhighlight %}

Les versions des images sont fixées aux dernières récentes à la date de redécation de cet article.

* hubtesting : c'est notre hub. Il ne faut pas oublier d'ouvrir le port 4444 qui va permettre aux futurs noeuds de s'y connecter
* chrometesting : notre premier noeud. On ouvre le port 5900 pour pouvoir se connecter au serveur VNC.
Le fait d'ajouter le service hub dans les links permet, à l'intérieur du futur container chrome testing, de contacter directement le hub grâce à http://hub plutôt que par son IP. Concrètement ce que Docker fait en buildant l'image c'est ajouter dans le fichier /etc/hosts une entrée du style "172.10.0.6 hub" (l'IP peut changer).
* firefoxtesting : idem à chrometesting, attention au changement de map du port 5900 (Docker n'autorisera pas que les deux noeuds soient mappés sur le même port)

#### Driver selenium pour behat et update de la conf

Il va falloir modifier notre composer.json pour ajouter le driver selenium
{% highlight yaml %}
"require-dev": {
    "sensio/generator-bundle": "~3.0",
    "symfony/phpunit-bridge": "~2.7",
    "behat/behat": "~3.0",
    "behat/mink": "~1.7",
    "behat/mink-extension": "~2.1",
    "behat/mink-browserkit-driver": "~1.3",
    "behat/symfony2-extension": "~2.1",
    "behat/mink-selenium2-driver": "~1.2"
}
{% endhighlight %}

Ensuite on va modifier la configuration de Behat pour ajouter notre extension Selenium

{% highlight yaml %}

default:
    suites:
        web:
            type: symfony_bundle
            bundle: AppBundle
            paths:
                - "/src/AppBundle/Tests/Scenarios"
            contexts:
                - AppBundle\Tests\Contexts\FeatureContext
            filters:
                tags: @web

        chrome_js:
            mink_session: default_session
            mink_javascript_session: chrome_javascript_session
            type: symfony_bundle
            bundle: AppBundle
            paths:
                - "/src/AppBundle/Tests/Scenarios"
            contexts:
                - AppBundle\Tests\Contexts\FeatureContext
            filters:
                tags: @testing_js

        firefox_js:
            mink_session: default_session
            mink_javascript_session: firefox_javascript_session
            type: symfony_bundle
            bundle: AppBundle
            paths:
                - "/src/AppBundle/Tests/Scenarios"
            contexts:
                - AppBundle\Tests\Contexts\FeatureContext
            filters:
                tags: @testing_js
                
    extensions:
        Behat\Symfony2Extension: ~
        Behat\MinkExtension:
            base_url: "http://fft-selenium.dev.zol.fr/app_dev.php"
            show_auto: true            
            show_cmd: 'chrome %s'
            sessions:
                default_session:
                    symfony2: ~
                chrome_javascript_session:
                    selenium2:
                        wd_host: "http://chrometesting:5555/wd/hub"
                        browser: chrome
                firefox_javascript_session:
                    selenium2:
                        wd_host: "http://firefoxtesting:5555/wd/hub"
                        browser: firefox      
{% endhighlight %}

Tout d'abord la configuration de l'extension. On rajoute deux sessions, une par noeud (navigateur). Vous puvez choisir ce que vous voulez comme nom de session, gardez simplement en tête que ce nom va être réutilisé dans la configuration des suites associées.
Pour chaque session on précise le paramètre wd_host, on indique au noeud l'url à utiliser pour se connecter au hub.
Cependant, si vous lancez les containers comme ça, ça ne peut pas encore marcher.
En effet le driver selenium pour behat s'execute au même endroit que les tests, c'est à dire le container web. Or celui ci ne connait pas le container chrometesting, ni firefoxtesting. A la place, il faudrait mettre l'IP, néanmoins celle ci est succeptible de changer à chaque build des images.

Pour pallier à ce problème on va utiliser le paramètre "link" de docker-compose :

web:
    extends:
        file: docker-compose-common.yml
        service: web
    environment:
        VIRTUAL_HOST: fft-selenium.dev.zol.fr
    links:
        - chrometesting
        - firefoxtesting

Cet ajout implique deux choses : d'une part ce qu'on voulait précédemment, c'est à dire pouvoir contacter le container chrometesting grâce à http://chrometesting (sans avoir besoin de l'IP), et d'autre part builder / lancer le container web buildera / lancera automatiquement les containers chrometesting et firefoxtesting (qui eux feront builder / lancer le container hubtesting).

La petite astuce à deviner ici c'était l'url précise ainsi que le port d'écoute pour les noeuds.

Enfin pour la session on précise le navigateur à utiliser (par défaut c'est firefox il me semble).

Maintenant on va créer deux suites qui utiliseront leur session respective, afin de lancer les tests sur les deux navigateurs. La configuration des suites est assez similaire à celle de web, avec la particularité qu'on indique quelle session utiliser en cas de scenario necessitant du javascript. Pour rappel, il suffit d'utiliser le tag @javascript sur un scenario pour indiquer à Mink d'utiliser le bon driver.

Petite touche personnelle : j'aime rajouter sur mes features un tag supplémentaire @web ou @testing_js pour la compréhension quand on est dans le développement de la feature. Cela permet de garder à l'esprit lorsqu'on écrit un test les différentes restrictions liées au driver (exemple : le "response status code" n'est pas disponible avec le driver selenium)





Concernant la propriété external_links des noeuds : c'est ici

docker run -d --name reverseproxy -p 80:80 -p 443:443 -v /var/run/docker.sock:/tmp/docker.sock jwilder/nginx-proxy