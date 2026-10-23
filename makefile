run-compose:
	docker compose up -d

down-compose:
	docker compose down

get-permission:
	sudo chmod 777 ./kafka-data/*