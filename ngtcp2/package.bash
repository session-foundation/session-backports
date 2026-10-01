# Sourced by build-deb.

SESSION_DEP=libngtcp2

# The OpenSSL backend needs OpenSSL's QUIC API, new in 3.5.  The distros with an older OpenSSL
# (bookworm, jammy, noble) have also never had ngtcp2's crypto-ossl packages, so there we build
# without them rather than backporting OpenSSL too.
prepare() {
    local ssl
    ssl=$(apt-cache policy libssl-dev | sed -n 's/^ *Candidate: *//p')
    if [ -z "$ssl" ] || [ "$ssl" = "(none)" ] || dpkg --compare-versions "$ssl" lt 3.5.1; then
        echo "libssl-dev ${ssl:-(none)} is older than 3.5.1; building without the OpenSSL backend"
        patch -p1 -F0 -E --no-backup-if-mismatch -i "$PKGDIR/no-openssl.patch"
    fi
}
