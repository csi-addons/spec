# Copyright 2021 The csi-addons Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SHELL:=/bin/bash

PROTOC_VERSION := 3.14.0
PROTOC_GEN_GO_VERSION := 1.25.0
PROTOC_GEN_GO_GRPC_VERSION := 1.1.0

PROTOC_FOUND := $(shell ./bin/protoc --version 2> /dev/null)
PROTOC_GEN_GO_FOUND := $(shell ./bin/protoc-gen-go --version 2>&1 | grep protoc-gen-go)
PROTOC_GEN_GO_GRPC_FOUND := $(shell ./bin/protoc-gen-go-grpc --version 2> /dev/null)


ifeq ("${PROTOC_FOUND}","libprotoc ${PROTOC_VERSION}")
	HAVE_PROTOC = "yes"
endif

ifeq ("${PROTOC_GEN_GO_FOUND}","protoc-gen-go v${PROTOC_GEN_GO_VERSION}")
	HAVE_PROTOC_GEN_GO = "yes"
endif

ifeq ("${PROTOC_GEN_GO_GRPC_FOUND}","protoc-gen-go-grpc ${PROTOC_GEN_GO_GRPC_VERSION}")
	HAVE_PROTOC_GEN_GO_GRPC = "yes"
endif


all: install-deps build

build: install-deps
	# generate libs
	./bin/protoc --go_out=lib/go --go_opt=paths=source_relative --plugin=./bin/protoc-gen-go replication/replication.proto
	./bin/protoc --go-grpc_out=lib/go --go-grpc_opt=paths=source_relative --plugin=./bin/protoc-gen-go-grpc replication/replication.proto

install-deps:
	mkdir -p bin dist google/protobuf
ifndef HAVE_PROTOC
	# download protoc
	wget -P dist/ --backups=1 \
		https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip
	unzip -jod bin dist/protoc-${PROTOC_VERSION}-linux-x86_64.zip bin/protoc

	# extract include/google/protobuf/descriptor.proto
	unzip -jod google/protobuf dist/protoc-${PROTOC_VERSION}-linux-x86_64.zip include/google/protobuf/descriptor.proto
endif

ifndef HAVE_PROTOC_GEN_GO
	# download protoc-gen-go
	wget -P dist/ --backups=1 \
		https://github.com/protocolbuffers/protobuf-go/releases/download/v${PROTOC_GEN_GO_VERSION}/protoc-gen-go.v${PROTOC_GEN_GO_VERSION}.linux.386.tar.gz
	tar -C bin -zxvf dist/protoc-gen-go.v${PROTOC_GEN_GO_VERSION}.linux.386.tar.gz protoc-gen-go
endif

ifndef HAVE_PROTOC_GEN_GO_GRPC
	# download protoc-gen-go-grpc
	wget -P dist/ --backups=1 \
		https://github.com/grpc/grpc-go/releases/download/cmd%2Fprotoc-gen-go-grpc%2Fv${PROTOC_GEN_GO_GRPC_VERSION}/protoc-gen-go-grpc.v${PROTOC_GEN_GO_GRPC_VERSION}.linux.386.tar.gz
	tar -C bin -zxvf dist/protoc-gen-go-grpc.v${PROTOC_GEN_GO_GRPC_VERSION}.linux.386.tar.gz ./protoc-gen-go-grpc
endif

check-changes:
	output=`git status -z *.go | tr '\0' '\n'`; if test -z "$$output"; then echo "all good"; else echo "files got changed" exit 1; fi

clean-deps:
	rm -rf bin dist google
