# Variants

Qubix OS is published as more than one image. The variants share everything except the
one dimension named in the table — same branding, same packages, same desktop sessions,
same flatpaks, same signing key.

| Variant | Image | Kernel | Requirements |
|---|---|---|---|
| **Standard** | `ghcr.io/qubik65536/qubix-os-bluebuild` | Fedora's, as shipped by Aurora DX | None beyond Aurora DX's |
| **CachyOS** | `ghcr.io/qubik65536/qubix-os-bluebuild-cachyos` | `kernel-cachyos` from COPR `bieszczaders/kernel-cachyos` | **x86-64-v3 CPU**, **Secure Boot off** |

Recipes: [`recipe.yml`](../recipes/recipe.yml) and
[`recipe-cachyos.yml`](../recipes/recipe-cachyos.yml). Both compose the same shared module
files (DD-016), so a package added to Qubix OS lands in both.

**Which should you run?** The standard image, unless you specifically want the CachyOS
kernel. It is the one Fedora tests, signs, and ships security updates for.

## The CachyOS variant

### What the kernel changes

CachyOS's kernel is a patched Linux kernel maintained by the CachyOS project, with an
official Fedora port in COPR [`bieszczaders/kernel-cachyos`][copr]. Headline differences:

| Area | Change |
|---|---|
| CPU scheduler | **BORE** (Burst-Oriented Response Enhancer) by default, tuned for desktop responsiveness |
| `sched_ext` | Supported, so pluggable BPF schedulers can be loaded |
| Networking | BBRv3 congestion control |
| Storage | Newer BTRFS/XFS and ZSTD work backported |
| Desktop/gaming | NTSync, HDR patches for AMD GPUs and gamescope, OpenRGB and ACS override support |
| Sources | Backports from `linux-next` and cherry-picks from Clear Linux |

[copr]: https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos/

### Before you rebase

**1. Check your CPU.** The default CachyOS kernel is compiled for the x86-64-v3
microarchitecture level (roughly Intel Haswell / AMD Excavator and newer). On an older
CPU it does not boot.

```bash
/lib64/ld-linux-x86-64.so.2 --help | grep 'x86-64-v3'
```

A line marked `(supported, searched)` means you are fine. If only `x86-64-v2` is
supported, do not use this variant — the COPR's `-lts` and `-server` kernels build for
v2, and adopting one is a recipe change, not a user choice.

**2. Turn off Secure Boot**, or enrol the kernel's signing key yourself. A COPR-built
kernel is not signed by Fedora's key. This is unrelated to this project's cosign
signature, which signs the *image* and is verified by `rpm-ostree`, not by firmware
(DD-008).

**3. Know what you give up:**

- Any prebuilt out-of-tree kernel module (`kmod-*`) inherited from Aurora is removed with
  Fedora's kernel — those RPMs are built against one exact kernel version. The build log
  lists what was installed before the swap.
- CachyOS stopped shipping prebuilt NVIDIA drivers in February 2026. On proprietary NVIDIA
  hardware, stay on the standard image.
- No Fedora QA. The kernel version follows CachyOS's releases and can change between two
  daily builds of this image.

### Installing

First install is two steps for the same reason as the standard image — the verification
policy ships inside the image (see [`usage.md`](usage.md)):

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/qubik65536/qubix-os-bluebuild-cachyos:latest
systemctl reboot
```

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/qubik65536/qubix-os-bluebuild-cachyos:latest
systemctl reboot
```

If you are already running the standard Qubix OS image, the policy is already installed —
one signed rebase is enough.

### Switching back

The variants are ordinary images, so switching either way is one rebase:

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/qubik65536/qubix-os-bluebuild:latest
systemctl reboot
```

`/home` and `/etc` are untouched. Nothing else about the system changes — the same
desktops, packages and configuration are on both sides.

**If the kernel does not boot**, pick the previous deployment from the boot menu (hold
`Esc`/`Shift` during boot), then `rpm-ostree rollback` or rebase back to the standard
image from there. Deployments are garbage-collected over time; the published standard
image is the durable fallback.

### Checking what you are running

```bash
uname -r                     # e.g. 7.1.3-cachyos1.fc44.x86_64
grep PRETTY_NAME /etc/os-release
```

| Variant | `PRETTY_NAME` |
|---|---|
| Standard | `Qubix OS (BlueBuild Image, Version: <IMAGE_VERSION>)` |
| CachyOS | `Qubix OS (BlueBuild Image, CachyOS Kernel, Version: <IMAGE_VERSION>)` |

`ID` and `NAME` are the same on both — it is the same distribution, built two ways.

## How the swap works

In [`common-kernel-cachyos.yml`](../recipes/common-kernel-cachyos.yml), in this order:

1. Enable the CachyOS kernel COPR.
2. Log the `kmod-*` packages that are about to be lost.
3. `dnf5 remove` Fedora's `kernel`, `kernel-core`, `kernel-modules`,
   `kernel-modules-core`, `kernel-modules-extra`.
4. Delete the stock kernel's `/usr/lib/modules/<kver>` directory, which RPM leaves behind
   with generated files in it.
5. `dnf5 install` `kernel-cachyos`, `kernel-cachyos-core`, `kernel-cachyos-modules`.
6. Assert exactly one kernel remains, with a `vmlinuz`.
7. (In the recipe.) Run the `initramfs` module — a kernel installed in a container build
   has no `initramfs.img` until something generates one.

**Removal must come before installation.** `kernel-cachyos-core` declares
`Provides: kernel`, so removing "kernel" afterwards would remove the new kernel. DD-017
records this and the rest of the reasoning.

## Adding another variant

1. Add a task in [`../.agent/plan.md`](../.agent/plan.md).
2. Create `recipes/recipe-<thing>.yml` with its own `name:`, composing `common-base.yml`
   and `common-identity.yml` plus whatever makes it different.
3. Put anything reusable in a `common-*.yml` file; never copy `common-base.yml`.
4. Add the recipe to the matrix **and** to the `workflow_dispatch` options in
   [`../.github/workflows/build.yml`](../.github/workflows/build.yml).
5. Add a row to the table at the top of this page and a `DD-###` record.
