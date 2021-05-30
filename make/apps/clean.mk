##
# CLEAN

.PHONY: clean app-clean
clean: app-clean docker-compose-down .env-clean ## Clean application and docker images

# target clean@%: Clean deployed application and docker images
.PHONY: clean@%
clean@%:
	$(call make,docker-compose-down DOCKER_COMPOSE_DOWN_OPTIONS='--rmi all -v')
