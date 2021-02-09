all: build


build: replication.proto
	protoc --go_out=lib/go --go_opt=paths=source_relative *.proto
	protoc --go-grpc_out=lib/go --go-grpc_opt=paths=source_relative *.proto