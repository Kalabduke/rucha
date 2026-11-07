FROM golang:1.21-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN go mod tidy && CGO_ENABLED=0 go build -o /out/rucha-api .

FROM alpine:3.19
RUN apk add --no-cache ca-certificates
COPY --from=build /out/rucha-api /app/rucha-api
WORKDIR /app
ENV PORT=8081 STATIC_DIR=/app/public
EXPOSE 8081
CMD ["/app/rucha-api"]
