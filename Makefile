# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2020
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

build:
	sudo docker-compose --file docker/main.yml --file docker/overlay.yml --file docker/demo.yml build --compress --force-rm
	sudo docker image prune --force
pull:
	sudo docker-compose --file docker/main.yml --file docker/overlay.yml --file docker/demo.yml pull

docker-deploy: docker-undeploy
	sudo docker-compose --file docker/main.yml --file docker/overlay.yml up --force-recreate --detach --no-build
docker-undeploy:
	sudo docker-compose --file docker/main.yml --file docker/overlay.yml down --remove-orphans
docker-deploy-demo: docker-undeploy-demo
	sudo docker-compose --file docker/main.yml --file docker/overlay.yml --file docker/demo.yml up --force-recreate --detach --no-build
docker-undeploy-demo:
	sudo docker-compose --file docker/main.yml --file docker/overlay.yml --file docker/demo.yml down --remove-orphans
docker-logs:
	for component in pgw sgw mme enb; do \
		docker logs docker_$${component}_1; \
	done
docker-debug:
	sudo docker-compose --file docker/main.yml --file docker/overlay.yml --file docker/demo.yml logs --follow external_client

k8s-deploy:
	cd ./k8s/"$${MULTI_CNI:-multus}"; ./deploy_main.sh
k8s-undeploy:
	cd ./k8s/"$${MULTI_CNI:-multus}"; ./undeploy_main.sh
k8s-deploy-demo:
	cd ./k8s/"$${MULTI_CNI:-multus}"; ./deploy_demo.sh
k8s-undeploy-demo:
	cd ./k8s/"$${MULTI_CNI:-multus}"; ./undeploy_demo.sh
k8s-logs:
	for component in pgw sgw mme enb; do \
		kubectl logs $${component} ; \
	done
k8s-debug:
	kubectl logs -f external-client
