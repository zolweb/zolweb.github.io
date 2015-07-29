---
layout: post
title: Les annotations avec Symfony
author: yannick_pereirareis
excerpt: "Le framework offre plusieurs formats (php, yaml, xml, annotations) pour la configuration de différents éléments :  mapping ORM/ODM, contraintes/assertions, sérialisation, routing, services, ... Cependant, afin d'augmenter la productivité de façon considérable, l'utilisation des annotations est un très bon choix."
tags: [symfony, configuration, yaml, yml, annotations, avantages, services]
comments: false
image:
  feature: headers/remotework.jpg
---

Lorsqu'il s'agit de définir un format de configuration (yaml, xml,...) lors de la mise en place d'un projet Symfony, on peut être confronté à des avis
et choix différents, et surtout à divers arguments en faveur ou en défaveur d'un format ou d'un autre.
Le choix que je propose et conseille généralement est celui des **annotations**... et je me fais très souvent crier dessus et l'on me repète les arguments suivants :

* Cela alourdi le code des fichiers PHP.
* Cela couple fortement le code au framework.
* Il est inaceptable de définir des configurations à travers des commentaires.
* Il faut utiliser le format XML pour avoir le support de l'autocomplétion.


Je vais donc vous exposer mon point de vue concernant ces arguments, et vous expliquer comment l'utilisation des **annotations**
peut augmenter votre productivité, réduire sensiblement la complexite d'une application et diminuer le nombre de fichiers de configurations.


## Mon point de vue sur les principaux arguments contre les annotations

### Le code PHP est alourdi

Je suis plutôt d'accord avec cet argument, on peut parfois se retrouver avec pas mal d'annotations dans un même fichier.
Ceci étant dit, tous les avantages que je tire de l'utilisation des annotations, me permet d'accepter cette relative compléxité supplémentaire de mon code.

### Le code est fortement couplé au framework

Encore une fois, je suis d'accord avec l'argument, mais je réponds souvent la chose suivante à cet arguments :

> ...les annotations entrainent un couplage fort du code avec le framework, **OUI ! Et alors ?**

* Le but d'un ORM/ODM n'est-il pas de coupler et créer un lien fort entre un système de persistance (SGBDR, NOSql,...)
et une classe/entité afin de récupérer les données sous forme d'objets ?

* Pensez vous qu'une classe contenant des attributs `private` ou `protected` et tous les `getter` et `setter`
afin de modifier les attributs soit vraiment une classe au sens **POO** ?

* Pourquoi faire le choix d'un framework (en fonction de ses avantages et inconvénients) et ne pas profiter
pleinement des possibilités qu'il offre en cherchant à respecter tout un tas de concepts à la mode ?

* Avez-vous réellement déjà réutilisé intégralement une classe PHP d'un projet dans un autre projet PHP ? Si vous l'avez fait il y a de grande chance que ce soit entre 2 projets Symfony, ce qui ne pose finalement pas de problème. Et si vous l'avez fait entre des projets PHP construit
avec des frameworks ou librairies différentes, vous avez surement dû supprimer quelques commentaires... Rien de grave.

**Attention !** Je ne suis aps en train de dire qu'il est recommandé de coupler son code au framework,
je dis que cela ne pose pas nécessairement de problème pour la majorité des projets.

Cependant, il y a en effet des situations dans lesquelles il faudra réfléchir avant d'utiliser des annotations :

* Une même entité hydratée depuis différentes sources (ORM, API, fichier,...)
* Un très gros projet, avec des règles métiers complexes, des très nombreuses configurations,...
* La reprise d'un projet sur lequel les annotations n'ont pas été utilisées (dans le but de ne pas multiplier les formats utilisés)
* Certaines annotations peuvent poser des problèmes de performance (@Template par exemple)


## Les points forts des annotations

### La configuration se trouve dans le fichier pour lequel on définie une configuration

* Plus de perte de temps passé à scroller à la recherche du bon fichier de configuration (qui peut éventuellement être dans les vendors).
* La modification d'un nom d'attribut, de fichier, de paramètre,... peut être très rapidement répercuté sur la configuration
* On minimise les effets de bord liés à une des modifications décrites dans le point précédent.

### On réduit considérablement le nombre de fichiers

En effet, avec les annotations on évite d'avoir des fichiers de configurations pour :

* Le mapping ORM/ODM
* La définition de services
* La sérialisation
* Les contraintes de validation
* Le routing
* Les rôles/droits

Et cela multiplié par le nombre de bundle mis en oeuvre.

### On évite les problème liés au nommage des fichiers

Certains fichiers de configurations doivent respecter un format précis ou se trouver à un emplacement précis
pour être correctement parser par Symfony et peuvent être à l'origine de pertes de temps importantes :

* Le mapping ORM/ODM
* Les règles de sérialisation
* ...


### De nombreux bundles utilisent ce format de configuration

Et oui ce format est très largement utilisé (et supporté) par les bundles les plus populaires :

* FOSRestBundle
* JMSDiExtraBundle (nous allons en reparler)
* NelmioApiDocBundle
* DoctrineBehaviors (attention à la version)


### On profite pleinement des `trait` 

De nombreux exemples types de cette optimisation de l'utilisation des annotations à travers les `trait` sont visibles
au sein du projet DoctrineBehaviors de KnpLabs.

{% highlight php startinline %}
<?php
namespace Knp\DoctrineBehaviors\Model\Timestampable;
trait Timestampable
{
    /**
     * @var \DateTime $createdAt
     *
     * @ORM\Column(type="datetime", nullable=true)
     */
    protected $createdAt;
    /**
     * @var \DateTime $updatedAt
     *
     * @ORM\Column(type="datetime", nullable=true)
     */
    protected $updatedAt;
    /**
     * Returns createdAt value.
     *
     * @return \DateTime
     */
    public function getCreatedAt()
    {
        return $this->createdAt;
    }
    /**
     * Returns updatedAt value.
     *
     * @return \DateTime
     */
    public function getUpdatedAt()
    {
        return $this->updatedAt;
    }
    /**
     * @param \DateTime $createdAt
     * @return $this
     */
    public function setCreatedAt(\DateTime $createdAt)
    {
        $this->createdAt = $createdAt;
        return $this;
    }
    /**
     * @param \DateTime $updatedAt
     * @return $this
     */
    public function setUpdatedAt(\DateTime $updatedAt)
    {
        $this->updatedAt = $updatedAt;
        return $this;
    }
    /**
     * Updates createdAt and updatedAt timestamps.
     */
    public function updateTimestamps()
    {
        if (null === $this->createdAt) {
            $this->createdAt = new \DateTime('now');
        }
        $this->updatedAt = new \DateTime('now');
    }
}
{% endhighlight %}

{% highlight php startinline %}
<?php
namespace Knp\DoctrineBehaviors\Model\SoftDeletable;
trait SoftDeletable
{
    /**
     * @ORM\Column(type="datetime", nullable=true)
     */
    protected $deletedAt;
    /**
     * Marks entity as deleted.
     */
    public function delete()
    {
        $this->deletedAt = new \DateTime();
    }
    /**
     * Restore entity by undeleting it
     */
    public function restore()
    {
        $this->deletedAt = null;
    }
    /**
     * Checks whether the entity has been deleted.
     *
     * @return Boolean
     */
    public function isDeleted()
    {
        if (null !== $this->deletedAt) {
            return $this->deletedAt <= (new \DateTime());
        }
        return false;
    }
    /**
     * Checks whether the entity will be deleted.
     *
     * @return Boolean
     */
    public function willBeDeleted(\DateTime $at = null)
    {
        if ($this->deletedAt === null) {
            return false;
        }
        if ($at === null) {
            return true;
        }
        return $this->deletedAt <= $at;
    }
    /**
     * Returns date on which entity was been deleted.
     *
     * @return DateTime|null
     */
    public function getDeletedAt()
    {
        return $this->deletedAt;
    }
    /**
     * Set the delete date to given date.
     *
     * @param DateTime|null $date
     * @param Object
     */
    public function setDeletedAt(\DateTime $date)
    {
        $this->deletedAt = $date;
        return $this;
    }
}
{% endhighlight %}
Les différents exemples de codes ci-dessus montre comment factoriser et mettre en oeuvre facilement le design pattern **Behavioral**.
Un simple `use Timestampable;` permet d'ajouter tout ce qu'il faut à une entité afin de gérer une date de création et de modification
des données mappées grâce à cette entité.


## JMSDiExtraBundle, le bundle indispensable

Ce bundle ajoute le support des annotations pour la gestion de la définition des services
et d'un tas de choses liés à leur configuration :

* Nom
* Tags (listeners, subscribers, forms)
* Injection par constructeur, setter, attribut
* Observeurs
* Validateurs

Mais voyons maintenant en quoi ce bundle augmente la productivité.

Prenons la configuration suivante :



Imaginons maintenant que nous soyons obligés de faire des modifications sur le code,
et voyons l'impact sur les configurations faites via les annotations :

### Renommage d'une classe

### Renommage d'une variable "injectée"

### Modification de l'ordre des dépendences injectées

### Rennomage d'une méthode `setter`

