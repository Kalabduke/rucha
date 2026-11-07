.RECIPEPREFIX = >
.PHONY: build run up down health

build:
> go mod tidy
> go build -o bin/rucha-api .

run:
> go run .

up:
> docker compose up --build

down:
> docker compose down

health:
> curl -s http://localhost:8081/api/health
