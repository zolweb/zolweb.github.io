# DETERMINE PLATFORM
ifeq (Darwin, $(findstring Darwin, $(shell uname)))
  PLATFORM := OSX
else
  PLATFORM := Linux
endif

# MAP USER AND GROUP FROM HOST TO CONTAINER
ifeq ($(PLATFORM), OSX)
  CONTAINER_USERNAME = root
  CONTAINER_GROUPNAME = root
  HOMEDIR = /root
  CREATE_USER_COMMAND =
else
  CONTAINER_USERNAME = dummy
  CONTAINER_GROUPNAME = dummy
  HOMEDIR = /home/$(CONTAINER_USERNAME)
  GROUP_ID = $(shell id -g)
  USER_ID = $(shell id -u)
  CREATE_USER_COMMAND = \
    groupadd -f -g $(GROUP_ID) $(CONTAINER_GROUPNAME) && \
    useradd -u $(USER_ID) -g $(CONTAINER_GROUPNAME) $(CONTAINER_USERNAME) && \
    mkdir -p $(HOMEDIR) &&
endif

# utility commands
AUTHORIZE_HOME_DIR_COMMAND = chown -R $(CONTAINER_USERNAME):$(CONTAINER_GROUPNAME) $(HOMEDIR) &&
EXECUTE_AS = sudo -u $(CONTAINER_USERNAME) HOME=$(HOMEDIR)

# If the first argument is one of the supported commands...
SUPPORTED_COMMANDS := requirements install update start stop restart state bash jkbuild bundle
SUPPORTS_MAKE_ARGS := $(findstring $(firstword $(MAKECMDGOALS)), $(SUPPORTED_COMMANDS))
ifneq "$(SUPPORTS_MAKE_ARGS)" ""
  # use the rest as arguments for the command
  COMMAND_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  # ...and turn them into do-nothing targets
  $(eval $(COMMAND_ARGS):;@:)
endif

step=--------------------------------
project=Blog ZOL
compose=docker-compose

all: help
help:
	@echo ""
	@echo "-- Help Menu"
	@echo ""
	@echo "   1.  make requirements         	- Install requirements"
	@echo "   2.  make install              	- Install $(project)"
	@echo "   3.  make update               	- Update $(project)"
	@echo "   4.  make start                	- Start $(project)"
	@echo "   5.  make stop                 	- Stop $(project)"
	@echo "   6.  make restart              	- Stop and start $(project)"
	@echo "   7.  make state                	- Etat $(project)"
	@echo "   8.  make bash                 	- Launch bash $(project)"
	@echo "   9.  make blog				- Create a new blog for project $(project)"
	@echo ""


# REQUIREMENT
install-docker:
	@echo "$(step) Installing docker $(step)"
	@curl -sSL https://get.docker.com/ubuntu/ | sudo sh

install-docker-compose:
	@echo "$(step) Installing docker-compose $(step)"
	@sudo bash -c "curl -L https://github.com/docker/compose/releases/download/1.1.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose"
	@sudo chmod +x /usr/local/bin/docker-compose

requirements: install-docker install-docker-compose

build: remove
	@echo "$(step) Building images docker $(step)"
	@$(compose) build

install: build bundle jkbuild start nginx-proxy

bundle:
	@echo "$(step) Bundler $(step)"
	@$(compose) run --rm web bash -ci '\
                $(CREATE_USER_COMMAND) \
                $(AUTHORIZE_HOME_DIR_COMMAND) \
                $(EXECUTE_AS) bundle install --path vendor/bundle && $(EXECUTE_AS) bundle update'

jkbuild:
	@echo "$(step) Jekyll build $(step)"
	@$(compose) run --rm web bash -ci '\
		$(CREATE_USER_COMMAND) \
		$(AUTHORIZE_HOME_DIR_COMMAND) \
		$(EXECUTE_AS) jekyll build'

update: install

up:
	@echo "$(step) Starting $(project) $(step)"
	@$(compose) up  web

start: up

stop:
	@echo "$(step) Stopping $(project) $(step)"
	@$(compose) stop

restart: stop start

state:
	@echo "$(step) Etat $(project) $(step)"
	@$(compose) ps

remove: stop
	@echo "$(step) Remove $(project) $(step)"
	@$(compose) rm --force

bash:
	@echo "$(step) Bash $(project) $(step)"
	@$(compose) run --rm web bash

nginx-proxy:
	@echo "Starting NGINX REVERSE PROXY"
	@$(shell docker run -d -p 80:80 -v /var/run/docker.sock:/tmp/docker.sock jwilder/nginx-proxy > /dev/null 2> /dev/null || true)
