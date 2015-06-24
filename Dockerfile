FROM ypereirareis/docker-node-modules

MAINTAINER Yannick Pereira-Reis <yannick.pereira.reis@gmail.com>

# Install common libs
RUN apt-get update && apt-get install -y \
	ruby \
	ruby-dev \
	make \
	gcc \
	rubygems-integration	

# Install jekyll

RUN gem install jekyll
RUN gem install jekyll-sitemap
RUN gem install bundler
RUN gem install octopress --pre

VOLUME ["/app"]

WORKDIR /app

EXPOSE 4000

CMD ["jekyll", "serve", "-H0.0.0.0"]
