---
layout: post
title: Comment bien commencer un projet Symfony
author: yannick_pereirareis
excerpt: "Lors de la création d'un nouveau projet, et notamment un projet Symfony, il est nécessaire de penser à un certain nombre de choses très importantes à mettre en place ou configurer. Nous allons en détailler certaines ici."
tags: [symfony, router, proxy, api]
comments: false
image:
  feature: headers/symfony.png
---

Lorsqu'on débute un nouveau projet Symfony il est important de penser à différentes choses **dès le début** du projet.
Certaines de ces choses simplifient les développements, d'autres les tests, d'autres encore les process de déploiement ou mise en production.
Voici donc une liste de recommandations que vous pouvez suivre... ou pas.

## Général

**Tout en Anglais**

Un peu de sérieux, les développements doivent se faire en Anglais. C'est l'unique référence en la matière.
Les libs et bundles tiers sont écrits en Anglais, ne mélangeons pas tout !

**Gestion des traductions et multilingue**

Avant même de commencer à développer,
il faut mettre en place ce mécanismes de gestion et centralisation des traductions pour les données statiques et données en base de données.

**Utiliser des variables d'environnements pour les configurations dépendantes de la plate forme**

Certaines configurations, mots de passe, clé de chiffrement sont spécifiques par environnement.
Il ne faut surtout pas les commiter. Il ne faut certainement pas non plus divulguer des informations de prod aux dev.
Utilisez donc les variables d'environnements pour définir ces configurations.

**Commande `composer update` interdite**

Ne jamais lancer cette commande de cette manière sans argument. Vous pourriez mettre à jour des dépendances sans vous en rendre compte et casser complètement votre application.

**Toujours pusher le `composer.lock`**

Ce fichier est indispensable, car il permet d'installer les vendors dans une version précise.
Sans ce fichier on ne maitrise pas la version installée de chaque dépendance.

**Un hook de pre-commit**

Cela peut-être très utile pour vérifier qu'il ne reste pas un `var_dump()` ou un `console.log()` dans le code.
Un hook peut aussi permettre de lancer les tests avant de faire le commit et le push.

**Version précise pour les dépendances**

Votre application fonctionne avec certaines dépendances. Elle ne fonctionnera peut-être plus avec une version postérieur.
Attention à bien spécifier les versions de vos dépendances (semver)

**Définir des formats**

Des normes, des formats, des règles pour les nom de fichers, nom de variables, clés de traductions...

**Industrialisation des environnements de dev**

Une solution à base de VirtualBox/Vagrant ou container docker s'avère très utile lorsqu'il s'agit de partager des envorinnement de dev.

**PSR-2, norme, gui de style**

Rien de plus à dire

**Cache et logs avec Vagrant**

Pour optimiser les perfs de votre application Symfony avec Vagrant, modifier la configuration par défaut des répertoires `app/cache` et `app/logs`.
Ecrire dans les répertoires partagé depuis la VM est parfois très lent. Pensez plutôt au `/dev/shm` si possible.


## Base de données

**Migrations**

Lors de la mise à jour d'une application en prod, il est courant de devoir modifier le schéma de la base de donnée.
Il est vivement recommandé de penser à la gestion des migrations !

**Recherche avancée**

Vous devez mettre en place un module de recherche avancé, une recherche tolérente aux fautes d'orthographes, faire des statistiques sur vos données, ... ?
Pensez à Elastic (Elasticsearch).

**Sauvegarde**

Avant de rencontrer des problèmes, mettez en place un mécanismes de sauvegarde de votre BDD.
Encore plus important, il faut vérifier que les backup fonctionnent en essayant de remonter un projet à aprtir d'un backup.

**Doctrine et les clé primaires**

Si vous voulez minimiser les problèmes potentiels avec l'utilisation de doctrine, utiliser systématiquement des clés primaires simples au format `INT`.
Pensez à bien ajouter une contrainte d'unicité sur la clé composée de référence vers d'autres tables.

**Les indexes**

Vous faites des requêtes ou des jointures sur des colonnes particulières de vos tables... Pensez aux indexes.

**EAV**

Dans certain cas, une modélisation de type EAV (Entity-Attribute-Value) peut rendre bien des services.

**Des préfixes pour les tables**

Afin d'éviter une collision entre différents modules ou bundles utilisant des tables en BDD, préfixez toujours vos tables correctement.


## Backend

* Use a great ENUM lib
* Never inject whole Container
* DDD ? CQRS ? EventSourcing ?
* Try to write all your configs with the same format (yml, xml, php, annotations)
* Use IoC when possible !
* Never use built-in doctrine shortcut (find, findOneBy, findAll...) => LAZY LOADING
* No form definition inside controllers (very dificult to mock)
* No doctrine query inside controllers (very difficult to mock)
* Write your own session management class
* Write your own logger class
* Always thinks about maintenance mode
* Always think about dev/prod fixtures
* Think about Custom domain exceptions
* Think about global Exception listener
* Use ParamConverters correctly
* Always check data server-side
* Separate concerns as much as you can
* Bind a model to a form
* Event subscribers and Listeners can become evil !!!!
* Use Doctrine Behaviors and traits

## Frontend

* Use grunt/gulp to manage assets
* Alaways use a css compiler (less/sass)
* Write clean Javascript with module, organisation even if no framework used.
* Expose the routing through your Javascript
* Use a Responsive CSS Framework

## Gestion de la qualité

* Less than 30 lines inside actions
* NEVER write business logic inside views (handlebars, mustache)
* Even if you do not make an API, think like if it is !
* Always include unit and functionnal tests libs (phpunit, atoum, phpspec, behat,...)
* PHPDoc (only useful doc)
* Write useful comments !
* Jenkins / GitlabCI, CircleCI
* Code review

## Quelques bundles incontournables

* **FOSUserBundle** pour la gestion de compte utilisateurs, droits, groupes,...
* **FOSRestBundle** pour la mise en place d'API Rest
* **JMSSerializerBundle** pour la gestion de la sérialization d'objets
* **JMSDiExtraBundle** pour une gestion simplifier de nombreuses configurations
* **JMSAopBundle** pour mettre en place de la programmation orientée aspect (comme son nom l'indique)
* **HautelookAliceBundle** pour gérer facilement les données minimales de vos projets
* **DoctrineMigrationsBundle** pour la gestion des migrations de BDD (une fois le projet en prod)
