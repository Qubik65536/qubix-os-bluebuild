# Variants

Qubix OS is published as more than one image. The variants share everything except the
one dimension named in the table — same branding, same packages, same desktop sessions,
same flatpaks, same signing key.

| Variant | Image | Kernel | Requirements |
|---|---|---|---|
| **Standard** | `ghcr.io/qubik65536/qubix-os-bluebuild` | Fedora's, as shipped by Aurora DX | None beyond Aurora DX's |
| **CachyOS** | `ghcr.io/qubik65536/qubix-os-bluebuild-cachyos` | `kernel-cachyos` from COPR `bieszczaders/kernel-cachyos` | **x86-64-v3 CPU**; Secure Boot off, or [your own key enrolled](#secure-boot) |

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

**2. Decide what to do about Secure Boot.** The CachyOS kernel is unsigned, so with
Secure Boot on it will not boot until you sign it yourself. Turning Secure Boot off is the
one-step answer; the [Secure Boot](#secure-boot) section below is the other one.

**3. Know what you give up:**

- Any prebuilt out-of-tree kernel module (`kmod-*`) inherited from Aurora is removed with
  Fedora's kernel and is **not** restored — those RPMs are built against one exact kernel
  version. Today that means `kmod-v4l2loopback` (virtual webcam devices, used by OBS and
  similar) and `kmod-xone` (Xbox One controller dongle), plus their userspace halves. The
  build log lists them before the swap.
- CachyOS stopped shipping prebuilt NVIDIA drivers in February 2026. On proprietary NVIDIA
  hardware, stay on the standard image.
- No Fedora QA. The kernel version follows CachyOS's releases and can change between two
  daily builds of this image.

Everything else that comes out with Fedora's kernel goes back in: the
libguestfs/`virt-v2v` stack and `virtualbox-guest-additions` only require `kernel`, which
the CachyOS kernel provides, and `kernel-cachyos-devel-matched` replaces
`kernel-devel-matched` so `akmods` still has headers.

### Secure Boot

The CachyOS kernel carries **no signature at all** — not Fedora's, not CachyOS's. (Checked
against the published RPM: the `vmlinuz` PE certificate table is empty and the kernel spec
has no signing step.) So there is no vendor key to enrol, and with Secure Boot enabled the
firmware's shim refuses to load it.

Two ways forward. Turning Secure Boot off in firmware is the honest, boring one, and it is
what most people do. If you want to keep Secure Boot on, you sign the kernel with a
Machine Owner Key (MOK) of your own — enrol once, then **re-sign after every update**.

> This project's cosign signature is a different mechanism entirely: it signs the *image*
> and is checked by `rpm-ostree` at rebase time, not by your firmware at boot (DD-008).
> A verified image and a Secure Boot–bootable kernel are independent properties.

`sbsigntools` and `mokutil` ship on this variant, so nothing needs layering first.

#### 1. Create a key (once)

`/etc` survives rebases and updates, so the key can live there.

```bash
sudo mkdir -p /etc/pki/qubix-mok
cd /etc/pki/qubix-mok
sudo openssl req -new -x509 -newkey rsa:2048 -nodes -days 3650 \
  -subj "/CN=$(hostname) local Secure Boot key/" \
  -keyout MOK.priv -outform DER -out MOK.der
sudo openssl x509 -inform DER -in MOK.der -outform PEM -out MOK.pem
sudo chmod 600 MOK.priv
```

Back `MOK.priv` up somewhere safe and keep it off shared storage — anything signed with it
is trusted by this machine at boot.

#### 2. Enrol it with shim (once)

```bash
sudo mokutil --import /etc/pki/qubix-mok/MOK.der   # asks for a one-time password
systemctl reboot
```

On the next boot, **MokManager** appears before the boot menu: choose *Enroll MOK* →
*Continue* → *Yes* → enter the one-time password. This step needs a physical console; it
cannot be done over SSH. Confirm afterwards:

```bash
mokutil --list-enrolled | grep -A1 'Subject:'
```

#### 3. Sign the deployed kernel (after every update)

`rpm-ostree` writes each deployment's kernel into `/boot`, and that copy is what the
bootloader loads. Sign it after the update finishes and **before** rebooting:

```bash
sudo mount -o remount,rw /boot 2>/dev/null || true
for k in /boot/ostree/*/vmlinuz-*; do
  sbverify --list "$k" >/dev/null 2>&1 && continue          # already signed
  sudo sbsign --key /etc/pki/qubix-mok/MOK.priv \
              --cert /etc/pki/qubix-mok/MOK.pem \
              --output "$k.signed" "$k" && sudo mv "$k.signed" "$k"
done
sbverify --list /boot/ostree/*/vmlinuz-*
```

The loop skips kernels that are already signed, so it is safe to re-run, and it covers
every deployment on the machine rather than only the newest.

You cannot sign the kernel inside the image instead: `/usr/lib/modules/<kver>/vmlinuz`
lives in the read-only, checksummed ostree deployment. The `/boot` copy is the only one
you own. That is also why this repeats — every update produces a new deployment with a
fresh, unsigned copy.

#### If you forget

The boot fails with a security-policy violation and **the previous deployment still
boots**, because its kernel is still signed. Pick it from the GRUB menu (hold `Esc` or
`Shift` during boot), sign the new deployment with the loop above, and reboot.

#### What Secure Boot does *not* enforce here

This kernel is built with `CONFIG_LOCK_DOWN_IN_EFI_SECURE_BOOT` and
`CONFIG_MODULE_SIG_FORCE` unset, so booting with Secure Boot on does **not** put it into
lockdown and does **not** require kernel modules to be signed. Its own in-tree modules are
signed at build time with a key embedded in the kernel; anything you build locally with
`akmods` will load regardless. Secure Boot on this variant therefore buys you a verified
boot chain, not a locked-down kernel.

#### The durable alternative

Signing per update is a chore. The fix is for the image to sign the kernel in CI, so each
machine only ever runs one `mokutil --import`. That needs a key pair whose private half
lives in a repository secret and never reaches a published layer — tracked as `IMG-009`.

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
2. Record the installed package list, and log the `kmod-*` packages that are about to be
   lost.
3. `dnf5 remove` Fedora's `kernel`, `kernel-core`, `kernel-modules`,
   `kernel-modules-core`, `kernel-modules-extra`.
4. Delete the stock kernel's `/usr/lib/modules/<kver>` directory, which RPM leaves behind
   with generated files in it.
5. `dnf5 install --setopt=tsflags=noscripts` `kernel-cachyos`, `kernel-cachyos-core`,
   `kernel-cachyos-modules`, `kernel-cachyos-devel-matched`.
6. Assert exactly one kernel remains, with a `vmlinuz`; run `depmod`; assert `modules.dep`
   now exists.
7. Diff the package list against step 2, log what the removal took, and reinstall the
   packages the CachyOS kernel can satisfy.
8. (In the recipe.) Run the `initramfs` module — a kernel installed in a container build
   has no `initramfs.img` until something generates one.

Two of those steps are not obvious:

**Removal must come before installation.** `kernel-cachyos-core` declares
`Provides: kernel`, so removing "kernel" afterwards would remove the new kernel.

**Scriptlets must be skipped, and `depmod` run by hand.** `kernel-cachyos-core`'s
`%posttrans` calls `kernel-install`, which a ublue base image hooks with
`05-rpmostree.install` → `dracut`. That dracut run fails — `modules.dep is missing. Did
you run depmod?` — because the CachyOS RPMs ship no `modules.dep` and nothing generates
one in a container. The failing scriptlet fails the whole build, so the install skips
scriptlets and the build runs the part that matters itself.

DD-017 records this and the rest of the reasoning.

## Adding another variant

1. Add a task in [`../.agent/plan.md`](../.agent/plan.md).
2. Create `recipes/recipe-<thing>.yml` with its own `name:`, composing `common-base.yml`
   and `common-identity.yml` plus whatever makes it different.
3. Put anything reusable in a `common-*.yml` file; never copy `common-base.yml`.
4. Add the recipe to the matrix **and** to the `workflow_dispatch` options in
   [`../.github/workflows/build.yml`](../.github/workflows/build.yml).
5. Add a row to the table at the top of this page and a `DD-###` record.
