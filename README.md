# ZOL - Blog

Built with:

* [Jekyll](http://jekyllrb.com/)
* [Docker](https://docs.docker.com/)
* [Docker compose](https://docs.docker.com/compose/)
* Jekyll Minimal Mistakes theme

Minimal Mistakes takes advantage of Sass and data files to make customizing easier. These features require Jekyll 2.x and will not work with older versions of Jekyll.

* [Documentation](http://mmistakes.github.io/minimal-mistakes/theme-setup/)
* [Github repository](https://github.com/mmistakes/minimal-mistakes)
* [Live version](http://mmistakes.github.io/minimal-mistakes/)

## Getting Started

Get this repository into your workspace:

```
git clone git@github.com:zolweb/zolweb.github.io.git && cd zolweb.github.io
```

Install the project thanks to the following [Makefile](./Makefile) command:

```
make install
```

If you want to run app with **drafts** in dev:

```
make jkbuild "\-\-drafts"
```

The [Makefile](./Makefile) runs containers thanks to [docker compose](https://docs.docker.com/compose/) and the very simple [docker-compose.yml](./docker-compose.yml) configuration file:

```lang
web:
  build: .
  volumes:
   - .:/app
  environment:
       VIRTUAL_HOST: blog.zol.dev
```

The [Makefile](./Makefile) contains everything needed to install [Docker](https://docs.docker.com/) and [docker compose](https://docs.docker.com/compose/) through `requirements` target.

## Access the blog in your browser

We are using an nginx reverse proxy to access our container for custom domain name or from outside world.

The nginx reverse proxy come from this docker image/repo: [https://github.com/jwilder/nginx-proxy](https://github.com/jwilder/nginx-proxy)

The docker run command for the proxy is set into the [Makefile](./Makefile) (nginx-proxy target)

Go to [http://blog.zol.dev](http://blog.zol.dev) to see the magic if everything is fine.
