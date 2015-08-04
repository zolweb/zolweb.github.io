---
layout: post
title: Catcher toutes les requêtes avec Symfony afin de réaliser un proxy applicatif
author: yannick_pereirareis
excerpt: "Lorsque l'on réalise une application, notamment lors du développement d'API ou avec l'utilisation de Framework Javascript, il arrive souvent que l'on soit obligé de réaliser un proxy à travers une application backend (pour éviter les erreurs CORS par exemple)"
tags: [symfony, router, proxy, api]
comments: true
image:
  feature: headers/symfony.png
---

Les bonnes pratiques de développement et les architectures applicatives, notamment pour les applications web, évoluent en permanence.
On trouve aujourd'hui énormément d'applications web développées de la manière suivante :

* Une ou plusieurs applications BACK en mode API (rest) développées avec un langage de type Java, Php,...
* Une application FRONT en mode client de l'API, développée en Javascript grâce à un framework de type AngularJs, Backbone,...


# Problématique

Dans une application architecturée de la façon décrite précédemment, il n'est pas rare de devoir appeler depuis le front des services/APIs BACK sur différents domaines.

Ceci pose plusieurs problèmes :

* Des erreurs [CORS (Cross-origin resource sharing)](https://en.wikipedia.org/wiki/Cross-origin_resource_sharing).
* L'exposition des URLs/domaines des différents BACK.
* La duplication de code entre les différents BACK (contrôle de données, gestion de droits, ...).
* ...


# Une solution possible

Afin de répondre à ces problématiques, il est possible de réaliser un proxy applicatif vers lequel **toutes** nos requêtes seront redirigées.
Au lieu de développer une application **proxy** supplémentaire, il est également possible de choisir un de nos BACK qui jouera ce rôle.

Cela implique généralement de catcher toutes les requêtes et de les rediriger vers une même action/fonction qui les traitera avant de les propager vers le BACK destinataire.
Il faudra également gérer la réponse afin de la retourner correctement au client.


## Mise en oeuvre avec Symfony

Afin de catcher toutes les requêtes et de les rediriger vers une même action grâce à Symfony, il faut modifier le paramétrage par défaut du router.
En effet, par défaut, le caractère "/" est utilisé par Symfony comme séparateur des différentes parties d'une route.

Ainsi, les requêtes suivantes devront matcher avec des routes Symfony :

{% highlight bash %}
GET http://domain.com/users/1/comments/15
GET http://domain.com/users/1/products
GET http://domain.com/products/1
{% endhighlight %}

Les routes correspondantes pourraient être :

{% highlight bash %}
_users_comments_single:
    pattern: /users/{id}/comments/{commend_id}
    defaults: { _controller: AcmeDemoBundle:User:getUserComment }
    
_users_products:
    pattern: /users/{id}/products
    defaults: { _controller: AcmeDemoBundle:User:getUserProducts }
    
_users_products_single:
    pattern: /products/{product_id}
    defaults: { _controller: AcmeDemoBundle:Product:get }
{% endhighlight %}

Dans le cas d'un proxy, nous souhaitons rediriger **toutes** les requêtes vers la même action du même contrôleur.
Il est ainsi nécessaire de dire à Symfony que le caractère "/" ne doit pas être traité comme un séparateur :

{% highlight bash %}
_proxy:
    pattern: /proxy/{all}
    defaults: { _controller: AcmeDemoBundle:Proxy:filter }
    requirements:
        all: ".+"
{% endhighlight %}

Pour passer par le proxy, les requêtes devront ressembler à ceci :

{% highlight bash %}
GET http://domain.com/proxy/users/1/comments/15
GET http://domain.com/proxy/users/1/products
GET http://domain.com/proxy/products/1
{% endhighlight %}

L'action de notre contrôleur proxy ressemblera à :

{% highlight php startinline %}
public function filter($all) {

    // Contrôle de données...
    // Vérification des droit utilisateurs...
    // Log de la requête...
    // Ajout d'une entrée dans une BDD externe...

    $client = new GuzzleHttp\Client();
    $res = $client->get('https://api.back.fr/'.$all);
    
    return new Response($res->getBody());
}
{% endhighlight %}

# Conclusion

L'utilisation d'un proxy applicatif peut avoir plusieurs avantages :

* La factorisation de logique métier, de contrôle de données et la factorisation de code en général.
* L'abstraction des différents BACK et le masquage des différents services pour le client.
* La gestion des problématiques CORS.
* La mise en place de restriction d'accès IP
* ...