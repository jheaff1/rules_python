# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

workspace(name = "rules_python")

load("//python:deps.bzl", "rules_python_deps")
rules_python_deps()

load("//python:extra_deps.bzl", "rules_python_extra_deps")
rules_python_extra_deps()

# Everything below this line is used only for developing rules_python. Users
# should not copy it to their WORKSPACE.

load("//:internal_deps.bzl", "rules_python_internal_deps")

rules_python_internal_deps()

load("//:internal_setup.bzl", "rules_python_internal_setup")

rules_python_internal_setup()

load("//python:repositories.bzl", "python_register_toolchains")
load("//python:versions.bzl", "MINOR_MAPPING")

python_register_toolchains(
    name = "python",
    # We always use the latest Python internally.
    python3_version = MINOR_MAPPING.values()[-1],
)

load("//gazelle:deps.bzl", "gazelle_deps")

# gazelle:repository_macro gazelle/deps.bzl%gazelle_deps
gazelle_deps()
