---
layout: post
title: Repositories en tant que services
author: mathieu_tuaillon
excerpt: "Déclarer ses repositories en tant que services afin de les injecter permet d'obtenir un code plus clair et plus simple à tester."
tags: [symfony, doctrine, design]
comments: false
image:
  feature: headers/symfony.png
---

# Se passer de l'EntityManager de Doctrine

Dans le développement Symfony2, une pratique assez courante est d'injecter l'EntityManager de Doctrine dans les services qui servent à manager les entités de l'application :

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
{% endhighlight %}

Pourtant, on utilise juste le repository concerné dans ce manager. On pourrait donc se contenter d'injecter uniquement cet élément.
Cette approche a ses avantages :

* le code est plus clair : on voit directement avec quelles entités l'objet va interagir
* les mocks et donc les tests seront plus simples à écrire

# Repositories en tant que services

Afin de pouvoir injecter facilement nos repositories, commençons par les déclarer en tant que services. Pour cela, on utilisera la [factory du conteneur de service](http://symfony.com/doc/current/components/dependency_injection/factories.html) :

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
        factory_service: doctrine.orm.default_entity_manager
        factory_method: getRepository
        arguments:
            - AppBundle\Entity\User
{% endhighlight %}

AppBundle/Resources/config/managers.yml
{% highlight yaml %}
services:
    manager.user:
        class: AppBundle\Manager\UserManager
        arguments:
            - %repository.user%
{% endhighlight %}

# Utiliser le repository pour sauvegarder les entités

Une problèmatique découle de ce mode de fonctionnement : on a toujours besoin d'accéder à l'EntityManager pour sauvegarder les entités. Pour palier à ça, il suffit d'ajouter une méthode save() dans les repositories.

On va d'abord définir une interface pour généraliser ce mécanisme :

{% highlight php startinline %}
namespace AppBundle\Repository;

use Doctrine\Common\Persistence\ObjectRepository;

interface EntityRepositoryInterface extends ObjectRepository
{
    public function save(EntityInterface $entity);
}
{% endhighlight %}

Les repositories vont pouvoir implémenter cette interface :

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

Le fait d'utiliser une interface va permettre également de supprimer la dépendance à Doctrine du manager, ce qui est toujours mieux pour un objet orienté métier :

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

    public function getUser($id)
    {
        $customer = $this
            ->userRepository
            ->findOneById($id)
{% endhighlight %}
