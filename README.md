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

The [Makefile](./Makefile) runs containers thanks to [docker compose](https://docs.docker.com/compose/) and the very simple [docker-compose.yml](./docker-compose.yml) configuration file:

```lang
web:
  build: .
  ports:
   - "80:4000"
  volumes:
   - .:/app
```

The [Makefile](./Makefile) contains everything needed to install [Docker](https://docs.docker.com/) and [docker compose](https://docs.docker.com/compose/) through `requirements` target.

## Access the blog in your browser

Go to [http://127.0.0.1](http://127.0.0.1) to see the magic if everything is fine.
