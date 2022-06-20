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

"""This file contains macros to be called during WORKSPACE evaluation.

For historic reasons, pip_repositories() is defined in //python:pip.bzl.
"""

load("//python/private:toolchains_repo.bzl", "resolved_interpreter_os_alias", "toolchains_repo")
load(
    ":versions.bzl",
    "DEFAULT_PY3_RELEASE_BASE_URL",
    "MINOR_MAPPING",
    "PLATFORMS",
    "PY2_TOOL_VERSIONS",
    "PY3_TOOL_VERSIONS",
    "get_release_url",
)

def py_repositories():
    # buildifier: disable=print
    print("py_repositories is a no-op and is deprecated. You can remove this from your WORKSPACE file")

########
# Remaining content of the file is only used to support toolchains.
########

def _python2_repository_impl_windows(rctx):
    msiexec = rctx.which("msiexec.exe")
    if not msiexec:
        fail("Unable to find msiexec.exe")

    rctx.report_progress("Fetching python2 MSI")

    rctx.download(**PY2_TOOL_VERSIONS["2.7.18_win"])
    msi_name = "python-2.7.18.amd64.msi"
    msi_path = str(rctx.path(msi_name)).replace("/", "\\")  # why is this necessary? (copied from rules 7zip)

    # msiexec seems to not like extracting to the current working directory, so extract to a folder named "python2"
    msi_target_dir = "python2"
    msi_target_path = str(rctx.path("python2")).replace("/", "\\")  # why is this necessary? (copied from rules 7zip)

    msi_extract_args = [
        msiexec,
        "/a",
        msi_path,
        "TARGETDIR=%s" % msi_target_path,
        "/qn",
    ]

    rctx.report_progress("Extracting %s" % msi_path)
    msi_extract_result = rctx.execute(msi_extract_args)

    if msi_extract_result.return_code != 0:
        err_message = msi_extract_result.stdout if msi_extract_result.stdout else msi_extract_result.stderr
        fail("Python2 MSI extraction failed: exit_code=%s\n\n%s" % (msi_extract_result.return_code, err_message))

    exec_python2_path = rctx.path("python2/python.exe")

    build_content="""

package(default_visibility = ["//visibility:public"])

# NOTE that python is included in the buildroot gcc toolchain

# See this comment for also excluing *.pyc files and __pycache__ files, which can trigger unneccessary rebuilds - https://github.com/bazelbuild/rules_python/pull/618#discussion_r802427673
filegroup(
    name = "runtime_files",
    srcs = glob(
        include = ["python2/**"],
        exclude = [
            # Exclude files with spaces in the name, as a workaround to https://github.com/bazelbuild/bazel/issues/4327
            "**/* *",
        ],
    ),
)

filegroup(
    name = "python_bin",
    srcs = ["{target_dir}/python.exe"],
)

py_runtime(
    name = "py2_runtime",
    files = [":runtime_files"],
    interpreter = "python_bin",
    python_version = "PY2",
)
    """.format(target_dir = msi_target_dir)
    rctx.file("BUILD.bazel", build_content)
    # rctx.template(
    #     "BUILD",
    #     Label("//third_party/python:BUILD.python2_windows.tpl"),
    #     {"%{target_dir}": msi_target_dir},
    # )

def __host_python2_impl_src(rctx):
    rctx.download_and_extract(**PY2_TOOL_VERSIONS["2.7.18_src"])
    build_content = """\
load("@rules_foreign_cc//foreign_cc:defs.bzl", "configure_make")
# load("@rules_python//python:defs.bzl", "py_runtime_pair")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "all_srcs",
    srcs = glob(
        include = ["**"],
        exclude = ["*.bazel"],
    ),
)

configure_make(
    name = "python2",
    build_data = select({
        "@platforms//os:macos": ["@subversion"],
        "//conditions:default": [],
    }),
    configure_options = [
        "CFLAGS='-Dredacted=\\"redacted\\"'",
        "--with-openssl=$EXT_BUILD_DEPS/openssl",
        "--with-zlib=$EXT_BUILD_DEPS/zlib",
        "--enable-optimizations",
    ],
    env = select({
        "@platforms//os:macos": {"AR": ""},
        "//conditions:default": {},
    }),
    features = select({
        "@platforms//os:macos": ["-headerpad"],
        "//conditions:default": {},
    }),
    # rules_foreign_cc defaults the install_prefix to "python". This conflicts with the "python" executable that is generated.
    install_prefix = "py_install",
    lib_source = ":all_srcs",
    # Build these targets to prevent the tests from running (which take a long time to run)
    targets = ["build_all", "altinstall"],
    out_binaries = [
        "python2.7",
    ],
    out_data_dirs = ["lib"],
    deps = [
        "@openssl",
        "@zlib",
    ],
)

filegroup(
    name = "python2_bin",
    srcs = [":python2"],
    output_group = "python2.7",
)

py_runtime(
    name = "py2_runtime",
    files = [":python2"],
    interpreter = "python2_bin",
    python_version = "PY2",
)
    """
    rctx.file("BUILD.bazel", build_content)

def _python2_repository_impl(rctx):
    """ Implementation of the host_python2 repository rule."""

    if "windows" in rctx.os.name:
        _python2_repository_impl_windows(rctx)
    else:
        __host_python2_impl_src(rctx)

python2_repository = repository_rule(
    implementation = _python2_repository_impl,
    doc = "Fetches the external tools needed for the Python2 toolchain.",
)


def _python3_repository_impl(rctx):
    if rctx.attr.distutils and rctx.attr.distutils_content:
        fail("Only one of (distutils, distutils_content) should be set.")

    platform = rctx.attr.platform
    python3_version = rctx.attr.python3_version
    python3_short_version = python3_version.rpartition(".")[0]
    release_filename = rctx.attr.release_filename
    url = rctx.attr.url

    if release_filename.endswith(".zst"):
        rctx.download(
            url = url,
            sha256 = rctx.attr.sha256,
            output = release_filename,
        )
        unzstd = rctx.which("unzstd")
        if not unzstd:
            url = rctx.attr.zstd_url.format(version = rctx.attr.zstd_version)
            rctx.download_and_extract(
                url = url,
                sha256 = rctx.attr.zstd_sha256,
            )
            working_directory = "zstd-{version}".format(version = rctx.attr.zstd_version)
            make_result = rctx.execute(
                ["make", "--jobs=4"],
                timeout = 600,
                quiet = True,
                working_directory = working_directory,
            )
            if make_result.return_code:
                fail(make_result.stderr)
            zstd = "{working_directory}/zstd".format(working_directory = working_directory)
            unzstd = "./unzstd"
            rctx.symlink(zstd, unzstd)

        exec_result = rctx.execute([
            "tar",
            "--extract",
            "--strip-components=2",
            "--use-compress-program={unzstd}".format(unzstd = unzstd),
            "--file={}".format(release_filename),
        ])
        if exec_result.return_code:
            fail(exec_result.stderr)
    else:
        rctx.download_and_extract(
            url = url,
            sha256 = rctx.attr.sha256,
            stripPrefix = rctx.attr.strip_prefix,
        )

    # Write distutils.cfg to the Python installation.
    if "windows" in rctx.os.name:
        distutils_path = "Lib/distutils/distutils.cfg"
    else:
        distutils_path = "lib/python{}/distutils/distutils.cfg".format(python3_short_version)
    if rctx.attr.distutils:
        rctx.file(distutils_path, rctx.read(rctx.attr.distutils))
    elif rctx.attr.distutils_content:
        rctx.file(distutils_path, rctx.attr.distutils_content)

    # Make the Python installation read-only.
    if "windows" not in rctx.os.name:
        exec_result = rctx.execute(["chmod", "-R", "ugo-w", "lib"])
        if exec_result.return_code:
            fail(exec_result.stderr)

    python_bin = "python.exe" if ("windows" in platform) else "bin/python3"

    build_content = """\
# Generated by python/repositories.bzl

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "files",
    srcs = glob(
        include = [
            "*.exe",
            "*.dll",
            "bin/**",
            "DLLs/**",
            "extensions/**",
            "include/**",
            "lib/**",
            "libs/**",
            "Scripts/**",
            "share/**",
        ],
        exclude = [
            "**/* *", # Bazel does not support spaces in file names.
        ],
    ),
)

filegroup(
    name = "includes",
    srcs = glob(["include/**/*.h"]),
)

cc_library(
    name = "python_headers",
    hdrs = [":includes"],
    includes = [
        "include",
        "include/python{python3_version}",
        "include/python{python3_version}m",
    ],
)

cc_import(
    name = "libpython",
    hdrs = [":includes"],
    shared_library = select({{
        "@platforms//os:windows": "python3.dll",
        "@platforms//os:macos": "lib/libpython{python3_version}.dylib",
        "@platforms//os:linux": "lib/libpython{python3_version}.so",
    }}),
)

exports_files(["{python_path}"])

py_runtime(
    name = "py3_runtime",
    files = [":files"],
    interpreter = "{python_path}",
    python_version = "PY3",
)


""".format(
        python_path = python_bin,
        python3_version = python3_short_version,
    )
    rctx.file("BUILD.bazel", build_content)

    return {
        "distutils": rctx.attr.distutils,
        "distutils_content": rctx.attr.distutils_content,
        "name": rctx.attr.name,
        "platform": platform,
        "python3_version": python3_version,
        "release_filename": release_filename,
        "sha256": rctx.attr.sha256,
        "strip_prefix": rctx.attr.strip_prefix,
        "url": url,
    }

python3_repository = repository_rule(
    _python3_repository_impl,
    doc = "Fetches the external tools needed for the Python3 toolchain.",
    attrs = {
        "distutils": attr.label(
            allow_single_file = True,
            doc = "A distutils.cfg file to be included in the Python3 installation. " +
                  "Either distutils or distutils_content can be specified, but not both.",
            mandatory = False,
        ),
        "distutils_content": attr.string(
            doc = "A distutils.cfg file content to be included in the Python3 installation. " +
                  "Either distutils or distutils_content can be specified, but not both.",
            mandatory = False,
        ),
        "platform": attr.string(
            doc = "The platform name for the Python interpreter tarball.",
            mandatory = True,
            values = PLATFORMS.keys(),
        ),
        "python3_version": attr.string(
            doc = "The Python version.",
            mandatory = True,
        ),
        "release_filename": attr.string(
            doc = "The filename of the interpreter to be downloaded",
            mandatory = True,
        ),
        "sha256": attr.string(
            doc = "The SHA256 integrity hash for the Python interpreter tarball.",
            mandatory = True,
        ),
        "strip_prefix": attr.string(
            doc = "A directory prefix to strip from the extracted files.",
            mandatory = True,
        ),
        "url": attr.string(
            doc = "The URL of the interpreter to download",
            mandatory = True,
        ),
        "zstd_sha256": attr.string(
            default = "7c42d56fac126929a6a85dbc73ff1db2411d04f104fae9bdea51305663a83fd0",
        ),
        "zstd_url": attr.string(
            default = "https://github.com/facebook/zstd/releases/download/v{version}/zstd-{version}.tar.gz",
        ),
        "zstd_version": attr.string(
            default = "1.5.2",
        ),
    },
)

# Wrapper macro around everything above, this is the primary API.
def python_register_toolchains(
        name,
        python3_version,
        distutils = None,
        distutils_content = None,
        register_toolchains = True,
        py3_tool_versions = PY3_TOOL_VERSIONS,
        **kwargs):
    """Convenience macro for users which does typical setup.

    - Create a repository for each built-in platform like "python_linux_amd64" -
      this repository is lazily fetched when Python is needed for that platform.
    - Create a repository exposing toolchains for each platform like
      "python_platforms".
    - Register a toolchain pointing at each platform.
    Users can avoid this macro and do these steps themselves, if they want more
    control.
    Args:
        name: base name for all created repos, like "python38".
        python3_version: the Python version.
        distutils: see the distutils attribute in the python3_repository repository rule.
        distutils_content: see the distutils_content attribute in the python3_repository repository rule.
        register_toolchains: Whether or not to register the downloaded toolchains.
        py3_tool_versions: a dict containing a mapping of version with SHASUM and platform info. If not supplied, the defaults
        in python/versions.bzl will be used
        **kwargs: passed to each python_repositories call.
    """
    base_url = kwargs.pop("base_url", DEFAULT_PY3_RELEASE_BASE_URL)

    if python3_version in MINOR_MAPPING:
        python3_version = MINOR_MAPPING[python3_version]

    # this registers toolchain for all platforms supported by standalone py toolchain (aarch64 apple, aarch64 lnux, x86_64 linux etc)
    # python2 will have one toolchain that supports only windows, and another which supports all but windows.
    # actually, the python2 repo will change depending on platform, so the toolchain can simply omit the platform it supports, as it will support the host platform
    # to be consistent, I should instead call python2_repository twice, once with platform as windows and another as None, in which case python is built from source

    # could use "@platforms//:incompatible" and select

    python2_repository(
        name=  "{name}_py2".format(name=name),
    )
    for platform in PLATFORMS.keys():
        sha256 = py3_tool_versions[python3_version]["sha256"].get(platform, None)
        if not sha256:
            continue

        (release_filename, url, strip_prefix) = get_release_url(platform, python3_version, base_url, py3_tool_versions)

        python3_repository(
            name = "{name}_{platform}".format(
                name = name,
                platform = platform,
            ),
            sha256 = sha256,
            platform = platform,
            python3_version = python3_version,
            release_filename = release_filename,
            url = url,
            distutils = distutils,
            distutils_content = distutils_content,
            strip_prefix = strip_prefix,
            **kwargs
        )

        if register_toolchains:
            native.register_toolchains("@{name}_toolchains//:{platform}_toolchain".format(
                name = name,
                platform = platform,
            ))

    resolved_interpreter_os_alias(
        name = name,
        user_repository_name = name,
    )

    toolchains_repo(
        name = "{name}_toolchains".format(name = name),
        user_repository_name = name,
    )
