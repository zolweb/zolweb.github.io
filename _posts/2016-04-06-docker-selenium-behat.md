---
layout: post
title: Tests fonctionnels avec Behat et Selenium sous Docker
author: christophe_hautenne
excerpt: "Automatiser des tests fonctionnels avec Behat est une chose courante et plutôt facile à mettre en place. Par contre, dès qu'il sagit de tester les fonctionnalités impliquant du javascript, la tâche est moins aisée. Voyons comment faire avec Selenium et Docker."
tags: [docker, selenium, behat, mink, test, fonctionnel, driver, docker-compose, vnc]
comments: true
image:
  feature: headers/behat.jpg
---

# Introduction

Pour les impatients ou les connaisseurs, si vous savez déjà tout (du moins pour notre sujet du jour), vous pouvez d'ores et déjà passer à la partie qui va vous intéresser : [Configuration](#configuration)

* D'une part, c'est un fait, le développement de tests est tout aussi important que le développement de la fonctionnalité elle même. Dans le monde du web et plus particulièrement le monde du PHP, Behat fait parti des incontournables, au même titre que PHPUnit, Atoum ..

* D'autre part, les sites webs offrant de plus en plus de fonctionnalités et notamment grâce au javascript, il est normal que les tests doivent suivre... Il est difficile d'imaginer une suite de tests efficace qui zapperait toute la partie interaction "directe" (comprenez sans rechargement de page) !

Behat utilise des "drivers" pour pouvoir se connecter à des émulateurs de browsers, headless ou non, avec chacun leurs avantages et inconvénients. Qui dit drivers dit API pour chacun d'entre eux, donc développement spécifique. Pour faciliter la vie des développeurs, il existe une extension développée pour Behat, Mink (pour vous faire une idée rapide => [Mink at a glance](http://mink.behat.org/en/latest/at-a-glance.html)). Elle permet de pouvoir changer de driver sans avoir à changer le code.

Pour des tests "classiques" et très simple à mettre en place, j'utilise Symfony2Extension, qui permet de faire des requêtes, tester des codes HTTP (200, 404, 403 ...), naviguer entre des pages ... mais pas d'interpréter du javascript. Donc pas d'ajax, pas d'animation, pas de script, rien.

La documentation de Behat est plutôt explicite sur ce point, il suffit de choisir un driver différent pour les tests JS. En théorie.
Oui parce qu’en pratique cela implique pour les tests JS d'avoir un navigateur (headless ou non, c'est à dire possibilité de voir le comportement en live) qui se lance avec la suite de tests Behat, et alors là c'est la débandade entre les connexions, le debug, le temps d’exécution (lancer un navigateur et émuler une réponse HTTP sont deux choses bien différentes) ...

Si vous avez lu d'autres articles de ce blog, vous aurez compris qu'en plus de cette configuration, il faut prendre en compte que nous travaillons avec Docker !

Pour faire simple, j'ai eu pour un projet à mettre en place des tests JS. Ayant déjà des tests Behat et sachant qu'il existait des drivers permettant de faire ce que je voulais, c'est tout naturellement que je me suis tourné vers Selenium et son driver correspondant pour Behat.
J'ai choisis Selenium pour plusieurs raisons, notamment des images officielles docker dont nous allons nous servir par la suite (Merci à @Yannick pour l'idée des images officielles).
Vous pourrez également retrouver un [comparatif des fonctionnalités d'autres drivers sur la documentation de Mink](http://mink.behat.org/en/latest/guides/drivers.html)

Venons en au cœur du sujet : j'ai trouvé TRES PEU de documentation sur comment utiliser Docker, Behat et Selenium ensemble. Il m'a fallu parfois deviner, expérimenter, essayer, avancer à tâtons pour en arriver au résultat final tant attendu. C'est pourquoi aujourd'hui je vous livre le fruit de mon travail, en espérant que je ferais gagner du temps de recherche à certains d'entre vous !

# Configuration

## Ressources et prérequis

Pour ce "tuto" et ces tuyaux, je m'appuie sur un projet de test appelé FFT - Selenium (vous verrez peut être des noms s'y reportant dans le code). Ce projet contient une page web avec un formulaire géré en javascript pour des besoins d'exemple.

Pour la suite, je pars du principe où vous avez des notions sur Docker (docker compose notamment) Behat et bien sûr Selenium.

Imaginons votre projet configuré de cette façon (certaines informations ont été volontairement retirées, n'ayant aucun intérêt pour l'exemple) :
Vous avez déjà une infrastructure docker, vous avez quelques tests behat "normaux" et vous voulez implémenter des tests javascripts avec selenium.

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

docker-compose.yml (le build docker/web utilise l'image docker ubuntu:14.04.3 plus PHP et nginx, ceci peut changer suivant votre contexte) :
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

_Note importante pour la suite: chez ZOL nous utilisons [une image nginx](https://github.com/jwilder/nginx-proxy) qui nous sert de reverse proxy (c'est en partie ce qui nous permet d'accéder à notre container web en tapant "http://fft-selenium.dev.zol.fr" rien qu'en ayant définit notre `VIRTUAL_HOST` dans la configuration du service)._

On va donc lancer ce reverse proxy, qu'on va appeler le plus subtilement du monde : `reverseproxy`.
_(Notez que vous pouvez aussi le définir en tant que service dans le fichier docker-compose)_

{% highlight bash %}

docker run -d --name reverseproxy -p 80:80 -p 443:443 -v /var/run/docker.sock:/tmp/docker.sock jwilder/nginx-proxy

{% endhighlight %}

### Commençons !

La première chose à faire, ce sont les containers Selenium. Comme promis, nous allons faire tourner tout ça sous Docker, or il existe sur le docker hub une multitude d'images couvrant de nombreux cas d'usage.

#### Rappel du fonctionnement de Selenium

Selenium fonctionne sur un principe de hub/nœud. Un hub est un "point central" auquel vont se connecter les nœuds, chacun représentant un browser spécifique, un device ... Le but est de lancer les tests sur différents navigateurs, soit différents nœuds, pour s'assurer du bon fonctionnement de l'application pour un panel de terminaux. On utilise pour le hub comme pour le nœud un même fichier .jar lancé sur une machine avec des options lui indiquant son rôle. Dans le cas du nœud, on passe des paramètres supplémentaires concernant les informations requises pour se connecter au hub.

![Schema Selenium](/images/2016-04-06/test-automation-with-selenium.jpg "Schema Selenium")
Crédits: [BioDesignAutomation](http://biodesignautomation.org/category/setting-up-a-keyword-driven/)

#### Choix des images

Il existe [un repo GitHub](https://github.com/SeleniumHQ/docker-selenium) contenant des images dockers pour Selenium qui vont nous intéresser. Deux façons de procéder sont possibles : soit on utilise plusieurs images, une pour le hub et une par nœud, soit une seul image "standalone" qui contient à la fois le hub et le nœud.

Pour ma part et pour l'exemple, j'utiliserai 3 images :

* selenium/hub
* selenium/node-chrome-debug
* selenium/node-firefox-debug

Je préfère la version "découplée" pour une simple raison : si demain nous avons besoin d'ajouter le navigateur Opera par exemple, il suffit de monter une image docker avec le fameux .jar pour Selenium et le driver Opera qui correspond. Restera plus qu'à se connecter au hub :). Une image standalone ne contient qu'un seul navigateur bien sûr.

Les images chrome et firefox debug ont la particularité d'embarquer un serveur VNC prêt à l'emploi, et c'est de cette façon que nous pourrons voir en live les tests s’exécuter.

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

Les versions des images sont fixées aux plus récentes à la date de rédaction de cet article.

* hubtesting : c'est notre hub. Il ne faut pas oublier d'ouvrir le port 4444 qui va permettre aux futurs nœuds de s'y connecter
* chrometesting : notre premier nœud. On ouvre le port 5900 pour pouvoir se connecter au serveur VNC.
Le fait d'ajouter le service hub dans les links permet, à l'intérieur du futur container chrome testing, de contacter directement le hub grâce à http://hub plutôt que par son IP. Concrètement ce que Docker fait en buildant l'image c'est ajouter dans le fichier /etc/hosts une entrée du style "172.10.0.6 hub" (l'IP peut changer).
* firefoxtesting : idem à chrometesting, attention au changement de map du port 5900 (Docker n'autorisera pas que les deux nœuds soient mappés sur le même port)

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

Tout d'abord la configuration de l'extension. On rajoute deux sessions, une par nœud (navigateur). Vous pouvez choisir ce que vous voulez comme nom de session, gardez simplement en tête que ce nom va être réutilisé dans la configuration des suites associées.
Pour chaque session on précise le paramètre `wd_host`, on indique au nœud l'url à utiliser pour se connecter au hub.
Cependant, si vous lancez les containers comme ça, ça ne peut pas encore marcher.
En effet le driver selenium pour behat s’exécute au même endroit que les tests, c'est à dire le container `web`. Or celui ci ne connaît pas le container `chrometesting`, ni `firefoxtesting`. A la place, il faudrait mettre l'IP, néanmoins celle ci est susceptible de changer à chaque build des images.

Pour pallier à ce problème on va utiliser le paramètre "link" de docker-compose :

{% highlight yaml %}
web:
    extends:
        file: docker-compose-common.yml
        service: web
    environment:
        VIRTUAL_HOST: fft-selenium.dev.zol.fr
    links:
        - chrometesting
        - firefoxtesting

{% endhighlight %}

Cet ajout implique deux choses : d'une part ce qu'on voulait précédemment, c'est à dire pouvoir contacter le container `chrometesting` grâce à http://chrometesting (sans avoir besoin de l'IP), et d'autre part builder / lancer le container `web` buildera / lancera automatiquement les containers `chrometesting` et `firefoxtesting` (qui eux feront builder / lancer le container `hubtesting`).

_Notez l'url à utiliser ainsi que le port d'écoute pour les nœuds : http://chrometesting:5555/wd/hub_

Enfin pour la session on précise le navigateur à utiliser (par défaut c'est firefox il me semble).

Il ne restera plus qu'à créer deux suites qui utiliseront leur session respective, afin de lancer les tests sur les deux navigateurs. La configuration des suites est assez similaire à celle de web, avec la particularité qu'on indique quelle session utiliser en cas de scenario nécessitant du javascript.

_Pour rappel, il suffit d'utiliser le tag @javascript sur un scenario pour indiquer à Mink d'utiliser le bon driver._

Etant donné que les tests webs et js sont dans le même dossier, j'utilise les tags pour filtrer les scenarios (@web pour les tests webs et @testing_js pour les tests javascripts). Vous pouvez ne pas utiliser de tags en déplacant les scenarios dans deux dossiers distincts, pensez simplement à modifier la propriété `paths` en conséquence


### Lancement des images

Discernons d'abord le rôle de chaque container : 
* `web` : c'est à partir de ce container qu'est lancée la commande behat (et donc le fichier behat.yml est interprété). C'est aussi sur ce container que sont joués les tests ne nécessitant pas de driver JS
* `hubtesting` : container servant de point central pour les nœuds selenium
* `chrometesting` / `firefoxtesting` : nœuds disposant d'un navigateur pour exécuter les tests javascripts

Dans un test behat, on ne mets jamais d'url absolue (http://mon-site-tout-beau.fr/controller/action), seulement des urls relatives (/controller/action), et c'est très bien comme ça. Le problème, c'est qu'il faut dire à behat quel est ce host !
Plus précisément, c'est mink qui a besoin de ce host. C'est ce qu'on a précisé avec `base_url` dans notre fichier behat.yml.
Si vous avez bien suivi, il va y avoir un problème : autant les tests webs qui sont exécutés sur le container `web` n'auront aucun soucis, car http://fft-selenium.dev.zol.fr, c'est lui même, autant pour les tests JS c'est une autre paire de manche, car `chrometesting` ne connaît pas cette url.

Il suffit de faire le test : connectez vous sur le container `web` et essayez de faire un wget de http://fft-selenium.dev.zol.fr, puis la même chose sur `chrometesting`. Vous verrez que dans le cas de `chrometesting`, vous obtiendrez une erreur.

Vous me direz : "Facile ! Il suffit de rajouter la propriété `link` dans la définition des services `chrometesting` et `firefoxtesting` et d'utiliser http://web à la place !"

Cependant, comme il y a déjà un lien de `web` vers `chrometesting` et `firefoxtesting`, si vous rajoutez l'inverse il va se produire une erreur soulevée par docker : `ERROR: Circular import between web and chrometesting`. Vous ne pouvez pas linker "vice et versa" deux containers.

Mais rassurez vous ! Il y a une solution !

Vous vous souvenez du reverseproxy ? Celui qui a enregistré fft-selenium.dev.zol.fr grâce à la propriété `VIRTUAL_HOST` ? Et bien il va nous servir !

Nous allons modifier un tant soit peu notre configuration des services `chrometesting` et `firefoxtesting` :

{% highlight bash %}

chrometesting:
    image: selenium/node-chrome-debug:2.48.2
    ports:
        # Port is used for VNC only
        - 5900:5900
    links:
        - hubtesting:hub
    external_links:
        - reverseproxy:fft-selenium.dev.zol.fr

firefoxtesting:
    image: selenium/node-firefox-debug:2.48.2
    ports:
        # Port is used for VNC only
        - 5901:5900
    links:
        - hubtesting:hub
    external_links:
        - reverseproxy:fft-selenium.dev.zol.fr

{% endhighlight %}

On utilise la propriété `external_links` de docker-compose, de cette façon on indique au container : "Hey ! Tu veux fft-selenium.dev.zol.fr ? Va demander à reverseproxy il sait quoi faire !". Si si, je vous jure.
De son côté, le `reverseproxy` connaît fft-selenium.dev.zol.fr, c'est même lui qui l'a enregistré.

Et voilà, on évite le circular import et nos nœuds connaissent fft-selenium.dev.zol.fr.


### S'assurer que tout fonctionne

A partir de maintenant, vous devriez pouvoir lancer vos images. Mais comment savoir si cette configuration farfelue fonctionne ?

* Récupérez l'IP de votre image `hubtesting` puis dans votre navigateur allez sur http://172.17.0.5:4444/grid/console (Remplacez l'IP par la votre). Vous devriez avoir une page de Selenium vous montrant vos deux nœuds, avec leur ip et leur navigareurs disponibles

* Récupérez l'IP d'un des nœuds puis dans votre navigateur allez sur http://172.17.0.6:5555/wd/hub (Remplacez l'IP par la votre). Cette fois çi vous devriez avoir une page listant les sessions ouvertes.

* Connectez vous au serveur VNC d'un des nœuds. Pour cela téléchargez un [client VNC](https://www.realvnc.com/download/viewer/) et lancez le. Mettez l'IP de votre nœud que vous souhaitez inspecter et connectez vous. Comme indiqué sur la page github de SeleniumHQ, le mot de passe demandé est "secret".

* Lancez les tests tels quels : vous n'avez pas encore de tests JS mais au moins cela vous assurera que tout fonctionne au niveau de la configuration de behat

Astuce : pour récupérer l'IP d'un container, disons `chrometesting` :
{% highlight bash %}
docker inspect fftselenium_chrometesting_1 | grep IPA # fftselenium_chrometesting_1 à remplacer par le nom de votre container
{% endhighlight %}


Le test ultime : si vous avez d'un côté votre page sur /wd/hub de votre nœud, et de l'autre la fenêtre VNC, cliquez sur "Create session". Un navigateur devrait s'ouvrir tout seul par magie :)


### Lancer les tests

Ouf, on arrive à la fin, il nous manque plus qu'un test JS à exécuter !


test_js.feature
{% highlight gherkin %}
@testing_js
Feature: Test javascript
    In order to make correct tests
    As a developper
    I need to be able to test javascript

    @javascript
    Scenario: Test javascript
        Given I go to "/"
        When I test javascript
        Then print current URL
{% endhighlight %}

FeatureContext.php
{% highlight php %}
/**
 * @Then I test javascript
 */
public function iTestJavascript() {
    $title = $this->getSession()->evaluateScript("return window.document.title;");
    echo 'I\'m correctly on the webpage entitled "'.$title.'"';
}
{% endhighlight %}

Et voilà ! Gardez votre fenêtre VNC dans un coin, ouvrez même en une deuxième sur le deuxième nœud, puis lancez les tests behats. Vous devriez avoir dans un premier temps le test web sans navigateur (aucune réaction dans les fenêtres), puis tour à tour les tests se jouer sur leur navigateur respectif !

Bon tests !