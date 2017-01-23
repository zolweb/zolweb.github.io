step=--------------------------------
project=Blog ZOL
projectCompose=blog-zol
composeFile=docker-compose-$(PROJECT_ENV).yml
compose = $(PROJECT_AS) docker-compose -f $(composeFile) -p $(projectCompose)

install: remove jkbuild jkserve

bundle:
	@echo "$(step) Bundler $(step)"
	@$(compose) run --rm web bash -ci '\
                bundle install --path vendor/bundle && \
                    bundle check && \
                    bundle update'

jkbuild:
	@echo "$(step) Jekyll build $(step)"
	@$(compose) run --rm web bash -ci '\
		bundle exec jekyll build'

jkserve:
	@echo "$(step) Jekyll Serve $(step)"
	@$(compose) up -d web

start: stop jkbuild jkserve

stop:
	@echo "$(step) Stopping $(project) $(step)"
	@$(compose) stop

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
