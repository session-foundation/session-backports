# One workflow per package, distro and architecture: each builds the package in that distro's
# builder image with build-deb, and on the canonical repository's default branch uploads it with
# ci-upload.sh.

registry = "registry.session.codes/"

canonical_repo = "session-foundation/session-backports"

packages = ["ngtcp2"]

# (family, codename, version suffix, architectures)
distros = [
    ("debian", "sid", "", ["amd64", "i386", "arm64", "armhf"]),
    ("debian", "forky", "~deb14", ["amd64", "i386", "arm64", "armhf"]),
    ("debian", "trixie", "~deb13", ["amd64", "i386", "arm64", "armhf"]),
    ("debian", "bookworm", "~deb12", ["amd64", "i386", "arm64", "armhf"]),
    ("ubuntu", "stonking", "~ubuntu2610", ["amd64", "arm64"]),
    ("ubuntu", "resolute", "~ubuntu2604", ["amd64", "arm64"]),
    ("ubuntu", "noble", "~ubuntu2404", ["amd64", "arm64"]),
    ("ubuntu", "jammy", "~ubuntu2204", ["amd64", "arm64"]),
]

# arch -> (agent platform, builder image variant, parallel jobs; the arm agents have 4 cores).
# 32-bit builds run in 32-bit images on the 64-bit agents of the same family.
arches = {
    "amd64": ("linux/amd64", "", 6),
    "i386": ("linux/amd64", "/i386", 6),
    "arm64": ("linux/arm64", "/arm64v8", 4),
    "armhf": ("linux/arm64", "/arm32v7", 4),
}

def workflow(ctx, package, family, codename, suffix, arch):
    platform, variant, jobs = arches[arch]
    image = registry + family + "-" + codename + "-builder" + variant
    return {
        "name": "%s %s %s (%s)" % (package, family.capitalize(), codename, arch),
        "labels": {"platform": platform, "backend": "docker"},
        "when": [{"event": ["push", "pull_request", "manual"]}],
        "steps": [
            {
                "name": "build",
                "image": image,
                "pull": True,
                "environment": {"JOBS": str(jobs)},
                "commands": ["./build-deb %s %s '%s'" % (package, codename, suffix)],
            },
            {
                "name": "upload",
                "image": image,
                "environment": {"SSH_KEY": {"from_secret": "SSH_KEY"}},
                "commands": [
                    "apt-get -o=Dpkg::Use-Pty=0 -q update",
                    "apt-get -o=Dpkg::Use-Pty=0 -q install --no-install-recommends -y openssh-client",
                    "./ci-upload.sh %s %s/%s %s" % (package, family, codename, arch),
                ],
                # The secret only exists for our own pushes; Woodpecker doesn't resolve secrets for
                # steps that won't run, so this keeps forks and pull requests from failing on it.
                "when": [{
                    "event": ["push", "manual"],
                    "repo": canonical_repo,
                    "branch": ctx.repo.default_branch,
                }],
            },
        ],
    }

def main(ctx):
    return [
        workflow(ctx, package, family, codename, suffix, arch)
        for package in packages
        for family, codename, suffix, archs in distros
        for arch in archs
    ]
