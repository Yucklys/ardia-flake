# ardia-flake

Nix package for [Ardia](https://ardia.dev), built from upstream's Linux
release tarball. A scheduled workflow checks for a new release every six
hours, builds it, and commits the bump; it also refreshes `nixpkgs`.

Upstream ships Linux builds only in some nightlies, so the package tracks the
newest release of any kind that carries `Ardia-*-linux-x64.tar.xz`.

## Use

```nix
inputs.ardia.url = "github:Yucklys/ardia-flake";
# then: inputs.ardia.packages.x86_64-linux.ardia
# or:   nixpkgs.overlays = [ inputs.ardia.overlays.default ];
```

```sh
nix run github:Yucklys/ardia-flake
```

## Sandbox

The store cannot hold a setuid helper, so Chromium needs unprivileged user
namespaces. NixOS allows them. Ubuntu 23.10+ restricts them through AppArmor;
grant them to every Ardia store path with:

```
abi <abi/4.0>,
include <tunables/global>

profile ardia-nix /nix/store/*-ardia-*/lib/ardia/chrome flags=(unconfined) {
  userns,
}
```

saved as `/etc/apparmor.d/ardia-nix` and loaded with
`sudo apparmor_parser -r /etc/apparmor.d/ardia-nix`.

## Update by hand

```sh
./update.sh        # rewrites sources.json, prints the new version if any
nix build .#ardia
```
