# Copyright 2022 The Bazel Authors. All rights reserved.
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

"""Load dependencies needed to by rules_python."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

# buildifier: disable=unnamed-macro
def rules_python_deps():
    """Load dependencies needed to by rules_python."""

    maybe(
        http_archive,
        name = "rules_foreign_cc",
        sha256 = "6041f1374ff32ba711564374ad8e007aef77f71561a7ce784123b9b4b88614fc",
        strip_prefix = "rules_foreign_cc-0.8.0",
        url = "https://github.com/bazelbuild/rules_foreign_cc/archive/0.8.0.tar.gz",
    )

    maybe(
        http_archive,
        name = "zlib",
        build_file = Label("//third_party/zlib:BUILD.zlib"),
        sha256 = "91844808532e5ce316b3c010929493c0244f3d37593afd6de04f71821d5136d9",
        strip_prefix = "zlib-1.2.12",
        urls = [
            "https://zlib.net/zlib-1.2.12.tar.gz",
            "https://storage.googleapis.com/mirror.tensorflow.org/zlib.net/zlib-1.2.12.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "openssl",
        build_file = Label("//third_party/openssl:BUILD.openssl"),
        sha256 = "892a0875b9872acd04a9fde79b1f943075d5ea162415de3047c327df33fbaee5",
        strip_prefix = "openssl-1.1.1k",
        urls = [
            "https://mirror.bazel.build/www.openssl.org/source/openssl-1.1.1k.tar.gz",
            "https://www.openssl.org/source/openssl-1.1.1k.tar.gz",
            "https://github.com/openssl/openssl/archive/OpenSSL_1_1_1k.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "rules_perl",
        sha256 = "a2a21b0e20b100f8411242dafcde4953e85c13fd3eefcb42868c7a5e8cd2774d",
        strip_prefix = "rules_perl-43d2db0aafe595fe0ac61b808c9c13ea9769ce03",
        urls = [
            "https://github.com/bazelbuild/rules_perl/archive/43d2db0aafe595fe0ac61b808c9c13ea9769ce03.zip",
        ],
    )
