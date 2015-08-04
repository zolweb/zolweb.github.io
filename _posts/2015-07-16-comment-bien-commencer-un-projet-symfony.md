---
layout: post
title: Comment bien commencer un projet Symfony
author: yannick_pereirareis
excerpt: "Lors de la création d'un nouveau projet, et notamment un projet Symfony, il est nécessaire de penser à un certain nombre de choses très importantes à mettre en place ou configurer. Nous allons en détailler certaines ici."
tags: [symfony, recommandations, bundles]
comments: true
image:
  feature: headers/symfony.png
---

Lorsqu'on débute un nouveau projet Symfony il est important de respecter un ensemble de choses **dès le début** du projet.
Certaines simplifient les développements, d'autres les tests, d'autres encore les process de déploiement ou mise en production.
Voici donc une liste de recommandations que vous pouvez suivre... ou pas.

* [Général](#gnral)
* [Base de données](#base-de-donnes)
* [Backend](#backend)
* [Frontend](#frontend)
* [Gestion de la qualité](#gestion-de-la-qualit)
* [Quelques bundles incontournables](#quelques-bundles-incontournables)

## Général

**Tout en Anglais**

Un peu de sérieux, les développements doivent se faire en Anglais. C'est l'unique référence en la matière.
Les libs et bundles tiers sont écrits en Anglais, ne mélangeons pas tout !

**Gestion des traductions et multilingue**

Avant même de commencer à développer,
il faut mettre en place ce mécanismes de gestion et centralisation des traductions pour les données statiques et données en base de données.

**Utiliser des variables d'environnements pour les configurations dépendantes de la plate forme**

Certaines configurations, mots de passe, clé de chiffrement sont spécifiques par environnement.
Il ne faut surtout pas les commiter. Il ne faut certainement pas non plus divulguer des informations de prod aux développeurs.
Utilisez des variables d'environnements pour définir ces configurations.

**Commande `composer update` interdite**

Ne jamais lancer cette commande de cette manière sans argument. Vous pourriez mettre à jour des dépendances sans vous en rendre compte et casser complètement votre application.

**Toujours pusher le `composer.lock`**

Ce fichier est indispensable, car il permet d'installer les vendors dans une version précise.
Sans ce fichier on ne maitrise pas la version installée de chaque dépendance.

**Un hook de pre-commit**

Cela peut-être très utile pour vérifier qu'il ne reste pas un `var_dump()` ou un `console.log()` dans le code.
Un hook peut aussi permettre de lancer les tests avant de faire le commit et le push.

**Version précise pour les dépendances**

Votre application fonctionne avec certaines dépendances. Elle ne fonctionnera peut-être plus avec une version postérieure.
Attention à bien spécifier les versions de vos dépendances (<a href='http://semver.org/' target='_blank'>semver</a>)

**Définir des formats**

Des normes, des formats, des règles pour les noms de fichers, nom de variables, clés de traductions...

**Industrialisation des environnements de dev**

Une solution à base de VirtualBox/Vagrant ou container docker s'avère très utile lorsqu'il s'agit de partager des environnements avec d'autres développeurs, ou sur plusieurs plateformes.

**PSR-2, norme, guide de style**

Rien à dire de plus

**Cache et logs avec Vagrant**

Pour optimiser les perfs de votre application Symfony avec Vagrant, modifier la configuration par défaut des répertoires `app/cache` et `app/logs`.
Ecrire dans les répertoires partagés depuis la VM est parfois très lent. Pensez à utiliser plutôt au `/dev/shm` si possible.

## Base de données

**Migrations**

Lors de la mise à jour d'une application en prod, il est courant de devoir modifier le schéma de la base de donnée.
Il est vivement recommandé de penser à la gestion des migrations et ce depuis le début du projet !

**Recherche avancée**

Vous devez mettre en place un module de recherche avancée, une recherche tolérente aux fautes d'orthographes, faire des statistiques sur vos données, ... ?
Pensez à <a href='https://www.elastic.co/' target='_blank'>Elasticsearch]</a>.

**Sauvegarde**

Avant de rencontrer des problèmes, mettez en place un mécanisme de sauvegarde de votre BDD.
Encore plus important, il faut vérifier que les backups fonctionnent en essayant de remonter un projet à partir d'un backup (très simple si vous utilisez docker).

**Doctrine et les clé primaires**

Si vous voulez minimiser les problèmes avec l'utilisation de doctrine, utiliser systématiquement des clés primaires simples au format `INT`.
Pensez à bien ajouter une contrainte d'unicité sur la clé composée de référence vers d'autres tables.

**Les indexes**

Vous faites des requêtes ou des jointures sur des colonnes particulières de vos tables... Pensez aux indexes.

**EAV (Entity-Attribute-Value)**

Dans certains cas, une modélisation de type EAV (Entity-Attribute-Value) peut rendre bien des services. <a href='https://en.wikipedia.org/wiki/Entity–attribute–value_model' target='_blank'>EAV</a>

**Des préfixes pour les tables**

Afin d'éviter une collision entre différents modules ou bundles utilisant des tables en BDD, préfixez toujours vos tables correctement.

## Backend

**Les constantes/enum**

La gestion des constantes de classe est souvent mal faite, un peu bancale et limite les possiblités offertes par le langage (typage par exemple).
L'utilisation d'une librairie dédiée à la gestion des constantes/enum s'avère très utile <a href='https://github.com/myclabs/php-enum' target='_blank'>https://github.com/myclabs/php-enum</a>


**Service container**

Si vous pouvez éviter d'injecter tout le container Symfony dans vos services, faites-le !
Cela augmentera la réutilisabilité de vos classes et services et permettra de les tester plus facilement.
Pensez à l'utilisation des interfaces.

**DDD / CQRS / Event Sourcing**

Votre application est grosse, complexe, très specifique ou contient enormément de règles métier.
Pourquoi ne pas envisager l'utilisation de concepts comme :

* DDD <a href='https://en.wikipedia.org/wiki/Domain-driven_design' target='_blank'>Domain Driver Design</a>
* CQRS <a href='https://en.wikipedia.org/wiki/Command_query_separation' target='_blank'>Command Query Responsibility Seggregation</a>
* Event Sourcing

**Configurations**

Afin d'éviter de perdre **enormément** de temps à naviguer entre votre code et vos fichiers de configuration,
à chercher la syntaxe correcte pour les configuration en PHP, en XML ou en JSON, à répercuter des modifications dans de nombreux fichiers de configurations,... je vous recommande :

* L'utilisation d'un seul et unique format de configuration, le YAML (qui est très répandu)
* L'utilisation des annotations pour :
    * le mapping ORM/ODM des entités
    * la configuration des repositories
    * la gestion des contraintes des attributs des entités
    * la gestion de la serialisation
    * la définition et l'injection de services (alias de services)

Certains diront qu'avec les annotations, on couple fortement notre code au Framework... **oui !** et alors ?

Je ne recommande cependant pas l'utilisation des annotations pour le codage de règles métiers.


**Find / FindBy / FindOneBy**

Attention à l'utilisation de ces méthodes magiques proposées nativement par Symfony et Doctrine.
En effet, il est primordial d'être conscient du fait que l'on peut se retrouver avec de gros problèmes de performances en utilisant ces méthodes
si on ne fait pas attention notamment au <a href='https://en.wikipedia.org/wiki/Lazy_loading' target='_blank'>Lazy Loading</a>.

**Formulaires**

Ne jamais définir et configurer un formulaire dans un controller.
Si vous le faites vous serez confronté à différents problèmes :

* Un code très lourd dans le contrôleur.
* Un formulaire impossible à réutiliser.
* Un formulaire compliqué à tester et à mocker.

Dans l'idéal, il vaut mieux lier un modèle/une classe à un formulaire.
Cela permet de manipuler un objet ensuite.

**DQL / Repositories**

Ne jamais écrire de DQL ou de requêtes SQL directement dans un contrôleur.
Si vous le faites vous serez confronté à différents problèmes :

* Un code très lourd dans le contrôleur.
* Une requête impossible à réutiliser.
* Une requête impossible à tester / mocker.

**Session**

Il peut être intéressant de ne pas utiliser directement le service `session`, mais de l'utiliser à travers un service custom.
Cela permet un niveau d'abstraction supplémentaire et permet d'ajouter potentiellement des traitements lors de la sauvegarde
ou la récupération de données en session :

* Serialisation / désérialisation de données complexes.
* Log d'information.
* Gestion unifiée des identifiants des données stockées en session.

**Logs / Logger**

Comme pour la session il peut être pertinent d'avoir son propre service de log.
Cela peut notamment permettre d'avoir facilement des logger custom implémentant tous la même interface :

* Log dans des fichiers (monolog).
* Log en BDD.
* Aucun log (les méthodes error, warn, ... ne font rien).
* Log dans la console.

**Maintenance applicative**

Lors de la mise à jour d'une application en PROD, il faut prévenir et les utilisateurs et bloquer l'application en présentant un message clair.

**Dev / Prod**

En dev et en prod les données utilisées ne sont pas (et ne doivent pas être) les mêmes.
Pensez aux fixtures en dev, et aux données minimales de fonctionnement en prod (liste d'utilisateurs, référentiels,...)

**Exceptions**

Dans de nombreux projets on retrouve un seul type de levée d'exception : `new \Exception('Raoul')`.
Cela ne permet pas de gérer et différencier facilement les exceptions. Il peut être bien de définir des exceptions custom
liées au métier, aux fonctionnalités, à un bundle,...:

* InactiveUserException()
* InvalidCsvFormatException()
* BadEmailFormatException()

Pourquoi pas un listener d'exception global ??


**Validation des données coté serveur**

Rien à dire de plus...


**Listeners / Subscribers**

Attention aux listeners et Subscribers. Ils permettent de faire de nombreux traitements intéressants.
Cependant, ils peuvent poser des problèmes parfois, notamment les listeners Doctrine.
Il faut bien être conscient de quand et pourquoi ces listeners sont être appelés, et plus important encore,
il faut savoir quand et comment les désactiver. Imaginez une migration de base de données qui met à jour
la date de modification de centaines d'entités. Si vous avez un `postLoad` listener sur cette entité vous pouvez avoir de gros problèmes.

**Timestampable / Translatable / Sluggable**

Rien à dire de plus... pensez-y !

## Frontend

**Assetic / Grunt / Gulp**

Assetic est beaucoup moins pratique à mettre en place et à utiliser que des solutions comme Grunt ou Gulp.
Je vous recommande d'utiliser `grunt` ou `gulp` couplé aux modules `npm` qui vont bien.
Pensez aussi à `bower` pour la gestion des dépendances et libs.

**CSS**

Un framework CSS responsive (bootstrap, Foundation, ...) !!!
Pensez aux différents points de ruptures, testez sur différents supports !

**Less / Sass**

Quel que soit le pré-processeur ou compilateur css, c'est selon moi indispensable.

**Javascript**

Si vous n'utilisez pas de Framework de type AngularJs, Ember.js, Backbone.js,... pensez tout de même à écrire du Javascript propre et modulaires.
Le code Javascript en vrac et sans organisation, c'est fini (et interdit).

**Routes**

Si vous utilisez Twig comme moteur de template front, et que votre code contient des appels Ajax, pensez à la gestion des routes en Javascript.
Pourquoi ne pas avoir un router Javascript ? Vous pouvez aller faire un tour sur <a href='https://github.com/FriendsOfSymfony/FOSJsRoutingBundle' target='_blank'>https://github.com/FriendsOfSymfony/FOSJsRoutingBundle</a>.


## Gestion de la qualité

Voici quelques idées qui pourront vous permettre d'augmenter la qualité de votre code et de vos projets :

* Un contrôleur ne doit pas contenir plus de 50 lignes de code.
* On ne doit jamais retrouver de règles métiers dans des templates.
   * Les règles ne sont pas réutilisables.
   * Les règles ne sont pas testables unitairement.
   * Les templates deviennent très sales.
* Utilisez des "Décorateurs" pour formatter correctement les données à transmettre aux vues.
* Mettez en place des libs de tests unitaires back (atoum/phpunit) et front (jasmine/karma...)
* Mettez en place une lib de tests fonctionnels (behat, protractor,...)
* De la PHPDoc et des commentaires **utiles** (expliquez pourquoi à on a besoin de ce bout de code, et non pas ce qu'il fait)
* Intégration continue (Jenkins, GitlabCI, CircleCI,...)
* Pair Programing
* Revue de code sur PR/MR

## Quelques bundles incontournables

* **(FOSUserBundle** pour la gestion de compte utilisateurs, droits, groupes,...
* **FOSRestBundle** pour la mise en place d'API Rest.
* **SyliusResourceBundle** qui permet d’exposer sous la forme d’une API REST des entités Doctrine.
* **JMSSerializerBundle** pour la gestion de la sérialization d'objets
* **JMSDiExtraBundle** pour une gestion simplifier de nombreuses configurations.
* **JMSAopBundle** pour mettre en place de la programmation orientée aspect (comme son nom l'indique).
* **HautelookAliceBundle** pour gérer facilement les données minimales de vos projets.
* **DoctrineMigrationsBundle** pour la gestion des migrations de BDD (une fois le projet en prod).
