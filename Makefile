# ===============================
# Makefile - Proyecto MLOps 2025-2
# ===============================
 
include .env
 
help:
	@echo ""
	@echo "Comandos disponibles:"
	@echo "  make build        - Construir todas las imágenes Docker"
	@echo "  make up           - Levantar el entorno con Docker Compose"
	@echo "  make down         - Detener todos los contenedores"
	@echo "  make ps           - Listar servicios activos"
	@echo "  make logs SVC=x   - Ver logs de un servicio"
	@echo "  make k8s-deploy   - Desplegar entorno en Minikube"
	@echo ""
 
build:
	docker compose build
 
up:
	docker compose up -d
 
down:
	docker compose down
 
ps:
	docker compose ps
 
logs:
	docker compose logs -f $(SVC)
 
k8s-deploy:
	kubectl apply -k k8s/overlays/minikube