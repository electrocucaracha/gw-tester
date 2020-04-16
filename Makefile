# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2020
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

build:
	@docker-compose --file docker/main.yml --file docker/network-overlay.yml --file docker/demo.yml build --compress --force-rm
	@docker image prune --force
logs:
	@docker-compose --file docker/main.yml --file docker/network-overlay.yml --file docker/demo.yml logs --follow
deploy: undeploy
	@docker-compose --file docker/main.yml --file docker/network-overlay.yml --file docker/demo.yml up --force-recreate --detach --no-build
undeploy:
	@docker-compose --file docker/main.yml --file docker/network-overlay.yml --file docker/demo.yml down --remove-orphans
