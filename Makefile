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

all:

check-changes:
	output=`git status -z *.go | tr '\0' '\n'`; if test -z "$$output"; then echo "all good"; else echo "files got changed" ; exit 1; fi

clean-deps:
	rm -rf bin dist github.com google

%:
	$(MAKE) -C identity $@
	$(MAKE) -C reclaimspace $@
	$(MAKE) -C replication $@
