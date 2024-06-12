# Copyright 2024 The csi-addons Authors. All rights reserved.
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

UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Detect and set OS, GOOS and GOARCH values
# GO* set of vars follow the golang conventions
# for protoc-gen-go and protoc-gen-go-grpc
# OS variable is used in case of protoc as they went
# with `osx` rather than the conventional, `darwin`
ifeq ($(UNAME_S),Linux)
	GOOS = linux
	OS = linux
	ifeq ($(UNAME_M),x86_64)
		ARCH = x86_64
		GOARCH = amd64
	else ifeq ($(UNAME_M),aarch64)
		ARCH = aarch_64
		GOARCH = arm64
	else ifeq ($(UNAME_M),i386)
		ARCH = x86_32
		GOARCH = 386
	else ifeq ($(UNAME_M),i686)
		ARCH = x86_32
		GOARCH = 386
	endif
else ifeq ($(UNAME_S),Darwin)
	GOOS = darwin
	OS = osx
	ifeq ($(UNAME_M),x86_64)
		ARCH = x86_64
		GOARCH = amd64
	else ifeq ($(UNAME_M),arm64)
		ARCH = aarch_64
		GOARCH = arm64
	endif
endif
