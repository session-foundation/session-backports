# Session deb backports

Builds newer versions of libraries Session software depends on, as debs for the Debian and Ubuntu
releases we support, for the https://deb.session.foundation apt repositories.

The versions built are the ones [session-deps](https://github.com/session-foundation/session-deps)
(a submodule here) pins for its static builds.  Only each recipe's version, download URL and hash
are used: the packages themselves are built from Debian packaging kept in this repository.

Currently backported: **ngtcp2**, for every distro (even sid's ngtcp2 is older than session-deps').

## Layout

| path | what |
| --- | --- |
| `<package>/debian/` | the package's packaging, started from Debian sid's |
| `<package>/package.bash` | `SESSION_DEP`, the session-deps recipe to take the version from, and an optional `prepare` function adapting the packaging to a distro |
| `<package>/*.patch` | packaging changes `prepare` applies on some distros |
| `build-deb` | builds one package for the distro it runs on |
| `ci-upload.sh` | uploads a CI build to builds.session.codes (the same script as the packaging repos', bar the paths) |
| `.woodpecker/build.star` | the CI workflows: one per package, distro and architecture |

## Versions

A backport of upstream version `X.Y.Z` is versioned `X.Y.Z-0+stfN` plus the distro's suffix
(`~deb13`, `~ubuntu2404`, none for sid).  The `0` revision puts it below every official packaging
of the same upstream version, so that the distro's own `X.Y.Z-1` (or `-1build1`, `-1ubuntu1`), a
Debian backport of it (`X.Y.Z-1~bpo13+1`) or an experimental upload (`X.Y.Z-1~exp1`) supersedes
ours.  The `+` keeps it above plain `X.Y.Z`, so that it satisfies `>= X.Y.Z` dependencies (from
symbols files, for instance); a `~` there would not.  The one release that doesn't supersede it is
an Ubuntu-only `X.Y.Z-0ubuntu1`.

The upstream version comes from session-deps and `N` from the top entry of
`<package>/debian/changelog`, which must be for the same upstream version: `build-deb` refuses to
build otherwise.  So:

- **New upstream version:** update the session-deps submodule, then add a changelog entry for
  `X.Y.Z-0+stf1` (distribution `unstable`).  Check the build log for `dpkg-gensymbols` warnings
  about new symbols, and add those to the `.symbols` files with the new version.
- **Packaging change, same upstream version:** add a changelog entry for `X.Y.Z-0+stf(N+1)`.

`build-deb` adds the per-distro changelog entry with the suffix itself.

A build is skipped, uploading nothing, when apt already offers the package at that version or
newer: from our main or `/staging` repo, or from the distro itself once it catches up.  So pushing
unrelated changes doesn't rebuild what's already published.

## Distro differences

`prepare` runs in the unpacked source tree before the build, and adapts the packaging to the distro
it's running on.  Changes go in patch files generated with `diff -u` (never hand-written), applied
with `patch -F0` so that drifted context fails rather than applying with fuzz.

For ngtcp2, `no-openssl.patch` drops the OpenSSL backend (the `libngtcp2-crypto-ossl*` packages)
where OpenSSL is older than 3.5, whose QUIC API it needs: bookworm, jammy and noble, which have
never had those packages.

## Building locally

`build-deb` configures apt and installs build dependencies, so run it as root in the distro's
builder image, with a copy of the repository (submodule included):

    docker run --rm -v "$PWD":/src:ro registry.session.codes/debian-bookworm-builder \
        bash -c 'cp -a /src /work && cd /work && ./build-deb ngtcp2 bookworm "~deb12"'

The packages end up in `build/<package>/` inside the container; mount a directory to copy them to
if you want them.

## CI and publishing

Every push, pull request and manual pipeline builds every package for every distro and
architecture.  Pushes (and manual pipelines) to the default branch of
`session-foundation/session-backports` also upload the packages, using the `SSH_KEY` secret, to

    builds.session.codes/session-foundation/session-backports/<package>/<family>-<codename>/

Publishing into the apt repository is the usual manual step with session-packaging's
`publish-debs.sh`, which publishes every package it finds there, as the
`session-foundation/session-backports/<package>` projects.

## Adding a package

1. Import Debian sid's packaging verbatim as `<package>/debian/` in a commit of its own, so later
   changes show as diffs against it.
2. Add `<package>/package.bash` setting `SESSION_DEP`, and a changelog entry as above.
3. Add the package to `packages` in `.woodpecker/build.star`.

Publishing (`publish-debs.sh` and the builds server's `build-latest.sh`) picks new packages up
without changes.
