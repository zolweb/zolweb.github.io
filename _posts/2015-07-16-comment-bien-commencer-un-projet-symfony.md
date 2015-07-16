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
Voici donc une liste de recommandations que vous puvez suivre... ou pas.

# Général

* Everything in english
* Always setup translations and multi
* Always use ENV variables for secured or "per environment" configuration
* Never run `composer update` !!!!
* Always commit/push your `composer.lock`
* Setup a pre-commit hook to check your code for `var_dump`, `exit`, `die`, `console.log`, ...
* Fix as much as possible your dependencies versions (semver)
* Define formats for : file names, translation keys, ...
* Use Docker or Vagrant to share (at least) dev environment
* Respect PSR-2
* cache / logs inside /dev/shm and not in shared folders with Vagrant

# Base de données

* Always setup database migrations
* Advanced search ?? => Elastic and FOSElasticaBundle
* Think about backup in production
* Always use a int primary key if you want to avoid some problem (unique constraint on composed key)
* DO NOT FORGET indexes
* EAV model could help you
* Use table name prefixes for YOUR tables
* Use a normalizer for doctrine configuration
* Use INT everywhere

# Backend

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

# Frontend

* Use grunt/gulp to manage assets
* Alaways use a css compiler (less/sass)
* Write clean Javascript with module, organisation even if no framework used.
* Expose the routing through your Javascript
* Use a Responsive CSS Framework

# Gestion de la qualité

* Less than 30 lines inside actions
* NEVER write business logic inside views (handlebars, mustache)
* Even if you do not make an API, think like if it is !
* Always include unit and functionnal tests libs (phpunit, atoum, phpspec, behat,...)
* PHPDoc (only useful doc)
* Write useful comments !
* Jenkins / GitlabCI, CircleCI
* Code review

# Quelques bundles incontournables

* **FOSUserBundle** pour la gestion de compte utilisateurs, droits, groupes,...
* **FOSRestBundle** pour la mise en place d'API Rest
* **JMSSerializerBundle** pour la gestion de la sérialization d'objets
* **JMSDiExtraBundle** pour une gestion simplifier de nombreuses configurations
* **JMSAopBundle** pour mettre en place de la programmation orientée aspect (comme son nom l'indique)
* **HautelookAliceBundle** pour gérer facilement les données minimales de vos projets
* **DoctrineMigrationsBundle** pour la gestion des migrations de BDD (une fois le projet en prod)
