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
SUPPORTED_COMMANDS := requirements build install update up stop restart state bash jkbuild bundle
SUPPORTS_MAKE_ARGS := $(findstring $(firstword $(MAKECMDGOALS)), $(SUPPORTED_COMMANDS))
ifneq "$(SUPPORTS_MAKE_ARGS)" ""
  # use the rest as arguments for the command
  COMMAND_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  COMMAND_ARGS := $(subst :,\:,$(COMMAND_ARGS))
  # ...and turn them into do-nothing targets
  $(eval $(COMMAND_ARGS):;@:)
endif

step=--------------------------------
project=Blog ZOL
projectCompose=blog-zol
composeFile=docker-compose-$(PROJECT_ENV).yml
compose = $(PROJECT_AS) docker-compose -f $(composeFile) -p $(projectCompose)

all: help
help:
	@echo ""
	@echo "-- Help Menu"
	@echo ""
	@echo "   1.  make install              	- Install $(project)"
	@echo "   2.  make update               	- Update $(project)"
	@echo "   3.  make start                	- Start $(project)"
	@echo "   4.  make stop                 	- Stop $(project)"
	@echo "   5.  make restart              	- Stop and start $(project)"
	@echo "   6.  make state                	- Etat $(project)"
	@echo "   7.  make bash                 	- Launch bash $(project)"
	@echo "   8.  make blog				- Create a new blog for project $(project)"
	@echo ""


build: remove
	@echo "$(step) Building images docker $(step)"
	@$(compose) build  $(COMMAND_ARGS)

install: remove build bundle jkbuild up

bundle:
	@echo "$(step) Bundler $(step)"
	@$(compose) run --rm web bash -ci '\
                $(CREATE_USER_COMMAND) \
                $(AUTHORIZE_HOME_DIR_COMMAND) \
                $(EXECUTE_AS) bundle install --path vendor/bundle && $(EXECUTE_AS) bundle check && $(EXECUTE_AS) bundle update'

jkbuild:
	@echo "$(step) Jekyll build $(step)"
	@$(compose) run --rm web bash -ci '\
		$(CREATE_USER_COMMAND) \
		$(AUTHORIZE_HOME_DIR_COMMAND) \
		$(EXECUTE_AS) bundle exec jekyll build $(COMMAND_ARGS)'

update: install

up:
	@echo "$(step) Starting $(project) $(step)"
	@$(compose) up -d web

stop:
	@echo "$(step) Stopping $(project) $(step)"
	@$(compose) stop

restart: stop up

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
	@echo "Removing NGINX REVERSE PROXY"
	@$(shell docker rm -f reverseproxy > /dev/null 2> /dev/null || true)
	@echo "Starting NGINX REVERSE PROXY"
	@$(shell docker run -d --name reverseproxy -p 80:80 -v /var/run/docker.sock:/tmp/docker.sock jwilder/nginx-proxy > /dev/null 2> /dev/null || true)

