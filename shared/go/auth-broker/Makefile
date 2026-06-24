.PHONY: test build proto-gen run

PROTO_ROOT := ../../../shared/contracts/proto
PROTO_FILE := auth_broker/v1/token.proto
PB_OUT := internal/transport/grpc/pb

test:
	go test ./...

build:
	go build -o bin/auth-broker ./cmd/broker

proto-gen:
	protoc -I $(PROTO_ROOT) \
		--go_out=$(PB_OUT) --go_opt=paths=source_relative \
		--go-grpc_out=$(PB_OUT) --go-grpc_opt=paths=source_relative \
		$(PROTO_ROOT)/$(PROTO_FILE)

run: build
	./bin/auth-broker
