---
layout: post
title: Repositories Doctrine en tant que services
author: mathieu_tuaillon
excerpt: "Déclarer ses repositories Doctrine en tant que services dans Symfony2 permet d'obtenir un code plus clair et plus simple à tester."
tags: [doctrine, repository, entity manager, symfony2, service container]
comments: false
image:
  feature: headers/symfony.png
---

Les repositories (ou dépôts) sont souvent incontournables au sein d'une application Symfony2. Voyons comment les utiliser de manière plus pertinente depuis nos objets métiers.

## Se passer de l'EntityManager de Doctrine

Une pratique assez courante dans le développement est d'injecter l'EntityManager de Doctrine dans les services qui servent à manager les entités afin d'accéder au repository qui nous intéresse :

{% highlight php startinline %}
namespace AppBundle\Manager;

use Doctrine\ORM\EntityManager;

class UserManager
{
    protected $entityManager;

    public function __construct(EntityManager $entityManager)
    {
        $this->entityManager = $entityManager;
    }

    public function getUser($id)
    {
        $user = $this
            ->entityManager
            ->getRepository('AppBundle\Entity\User')
            ->findOneById($id)
        ;
    }
}
{% endhighlight %}

Pourtant, on utilise souvent juste le repository concerné : on pourrait donc se contenter de passer uniquement cet élément à notre objet et non l'EntityManager (de la même manière que l'on évite d'injecter le conteneur de services).
Cette approche a plusieurs avantages :

* le code est plus clair et plus simple : on voit directement avec quelles entités l'objet va interagir
* les mocks et donc les tests seront plus simples à écrire

## Repositories en tant que services

Afin de pouvoir injecter facilement nos dépôts, commençons par les déclarer en tant que services. Pour cela, on utilisera la [factory du conteneur de service](http://symfony.com/doc/current/components/dependency_injection/factories.html) :

AppBundle/Resources/config/services.yml
{% highlight yaml %}
imports:
    - { resource: repositories.yml }
    - { resource: managers.yml }
{% endhighlight %}

AppBundle/Resources/config/repositories.yml
{% highlight yaml %}
services:
    repository.user:
        class: Doctrine\ORM\EntityRepository
        factory: [@doctrine.orm.default_entity_manager, getRepository]
        arguments:
            - AppBundle\Entity\User
{% endhighlight %}

A noter si vous utilisez une version de Symfony inférieure à 2.6, il faudra utiliser l'ancienne manière d'utiliser la factory (merci à @FlavienMetivier pour l'information) :

{% highlight yaml %}
    factory_service: doctrine.orm.default_entity_manager
    factory_method: getRepository
{% endhighlight %}

AppBundle/Resources/config/managers.yml
{% highlight yaml %}
services:
    manager.user:
        class: AppBundle\Manager\UserManager
        arguments:
            - %repository.user%
{% endhighlight %}

## Utiliser le dépôt pour sauvegarder les entités

Une problèmatique découle de ce mode de fonctionnement : on a toujours besoin d'accéder à l'EntityManager pour sauvegarder les entités. Pour palier à ça, il suffit d'ajouter une méthode save() dans les repositories.

On va d'abord définir une interface afin de généraliser ce mécanisme :

{% highlight php startinline %}
namespace AppBundle\Repository;

use Doctrine\Common\Persistence\ObjectRepository;
use AppBundle\Entity\EntityInterface;

interface EntityRepositoryInterface extends ObjectRepository
{
    public function save(EntityInterface $entity);
}
{% endhighlight %}

Les repositories vont ensuite pouvoir implémenter cette interface :

{% highlight php startinline %}
namespace AppBundle\Repository;

use Doctrine\ORM\EntityRepository;
use AppBundle\Entity\User;

class UserRepository extends EntityRepository implements EntityRepositoryInterface
{
    public function save(User $user)
    {
        $this->_em->persist($user);
        $this->_em->flush();
    }
}
{% endhighlight %}

Le fait d'utiliser une interface va également permettre de supprimer le couplage à Doctrine du manager. Voici à quoi ressemble le code final du manager après ces modifications :

{% highlight php startinline %}
namespace AppBundle\Manager\UserManager;

use AppBundle\Repository\EntityRepositoryInterface;

class UserManager
{
    protected $userRepository;

    public function __construct(EntityRepositoryInterface $userRepository)
    {
        $this->userRepository = $userRepository;
    }

    public function createUser()
    {
        $user = new User();
        $this->userRepository->save($user);
    }
}
{% endhighlight %}
