#!/usr/bin/env python3
"""Package a raw disk image as an OVA. Runs inside the builder container
(called by scripts/build.sh).

Usage: scripts/make-ova.py <template> <platform> <outdir>

  <outdir>/<image>-<platform>.img       (disk 1: ESP + Btrfs)
  <outdir>/<image>-<platform>-swap.img  (disk 2: swap)
    -> <ova name>-disk1.vmdk, -disk2.vmdk (qemu-img, streamOptimized)
    -> <ova name>.ovf          (platforms/<platform>/ovf/*.in)
    -> <ova name>.mf           (SHA256 of .ovf and the .vmdk files)
    -> <outdir>/<ova name>.ova (tar: .ovf, .mf, .vmdk files) + .ova.sha256

Settings come from the shell environment of scripts/lib/common.sh
(load_env + load_template), read here by sourcing the same files.
"""

import hashlib
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import xml.etree.ElementTree as ET
from pathlib import Path
from string import Template
from xml.sax.saxutils import escape

REPO = Path(__file__).resolve().parent.parent

NS = {
    "ovf": "http://schemas.dmtf.org/ovf/envelope/1",
    "rasd": "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData",
    "vssd": "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData",
    "vmw": "http://www.vmware.com/schema/ovf",
}
OVF = "{%s}" % NS["ovf"]

OS_NAMES = {"debian": "Debian", "nixos": "NixOS"}

# ustar can't store files of 8 GiB or more.
USTAR_MAX = 8 * 1024**3 - 1


def log(msg):
    print(msg, flush=True)


def die(msg):
    print(f"error: {msg}", file=sys.stderr, flush=True)
    sys.exit(1)


def load_settings(template, platform):
    """Environment after load_env + load_template + platform vars, using
    the same shell code as the other scripts."""
    script = f"""
set -euo pipefail
. "{REPO}/scripts/lib/common.sh"
load_env
load_template "$1"
template_supports "$2" || die "$1 does not support platform '$2'"
for f in "{REPO}/platforms/$2/ovf/hardware.env" "{REPO}/platforms/$2/$OS/vars.env"; do
  if [ -f "$f" ]; then set -a; . "$f"; set +a; fi
done
export OVA_FILE="$(ova_file "$2")" IMAGE_FILE="$(image_file "$2")" SWAP_IMAGE_FILE="$(swap_image_file "$2")"
env -0
"""
    out = subprocess.run(
        ["bash", "-c", script, "bash", template, platform],
        check=True, stdout=subprocess.PIPE,
    ).stdout
    env = {}
    for item in out.split(b"\0"):
        if b"=" in item:
            k, v = item.split(b"=", 1)
            env[k.decode()] = v.decode()
    return env


def product_name(env):
    roles = " ".join(r.replace("-", " ").title() for r in env.get("ROLES", "").split())
    name = (env["PRODUCT_NAME"]
            .replace("{os}", OS_NAMES.get(env["OS"], env["OS"].capitalize()))
            .replace("{ver}", env["VER"])
            .replace("{role}", roles))
    return re.sub(r"\s+", " ", name).strip()


def product_version(env):
    # {timestamp} = build ID (start time, YYYYMMDDhhmm, from build.sh), or now.
    stamp = env.get("ID") or time.strftime("%Y%m%d%H%M")
    return env.get("PRODUCT_VERSION", "").replace("{timestamp}", stamp)


def product_info(env):
    # OVF order: Product, Vendor, Version, FullVersion, ProductUrl, VendorUrl.
    version = product_version(env)
    fields = [
        ("Product", product_name(env)),
        ("Vendor", env.get("VENDOR", "")),
        ("Version", version),
        ("FullVersion", version),
        ("ProductUrl", env.get("PRODUCT_URL", "")),
        ("VendorUrl", env.get("VENDOR_URL", "")),
    ]
    return "\n".join(f"      <{tag}>{escape(val)}</{tag}>" for tag, val in fields if val)


def render(path, values):
    """string.Template with every value XML-escaped (safe in text and in
    double-quoted attributes). Keys ending in _xml are inserted as is."""
    safe = {}
    for k, v in values.items():
        safe[k] = v if k.endswith("_xml") else escape(str(v), {'"': "&quot;"})
    try:
        return Template(path.read_text()).substitute(safe)
    except KeyError as e:
        die(f"{path.relative_to(REPO)}: no value for ${e.args[0]}")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def validate_schema(ovf_path):
    """xmllint against the DMTF OVF 1.1 schemas in scripts/schemas/ovf/,
    offline (catalog.xml maps the imported schema URLs to local files)."""
    xsd = REPO / "scripts" / "schemas" / "ovf"
    res = subprocess.run(
        ["xmllint", "--nonet", "--noout", "--schema", str(xsd / "dsp8023_1.1.0.xsd"), str(ovf_path)],
        env={**os.environ, "XML_CATALOG_FILES": str(xsd / "catalog.xml")},
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    if res.returncode != 0:
        die("OVF schema validation failed:\n" + res.stdout)
    log("OVF schema ok (DMTF OVF 1.1)")


def check_ovf(ovf_path, disks_expected):
    """Structural checks of the generated OVF. disks_expected:
    [(disk id, vmdk path, capacity GiB), ...] in disk order."""
    root = ET.parse(ovf_path).getroot()
    problems = []

    files = {f.get(OVF + "id"): f for f in root.iter(OVF + "File")}
    disks = {d.get(OVF + "diskId"): d for d in root.iter(OVF + "Disk")}
    networks = {n.get(OVF + "name") for n in root.iter(OVF + "Network")}

    if sorted(disks) != sorted(did for did, _, _ in disks_expected):
        problems.append(f"disks {sorted(disks)} != {[did for did, _, _ in disks_expected]}")
    for did, vmdk_path, gb in disks_expected:
        d = disks.get(did)
        if d is None:
            continue
        f = files.get(d.get(OVF + "fileRef"))
        if f is None:
            problems.append(f"Disk {did}: unknown fileRef")
            continue
        if f.get(OVF + "href") != vmdk_path.name:
            problems.append(f"Disk {did}: href {f.get(OVF + 'href')} != {vmdk_path.name}")
        if int(f.get(OVF + "size")) != vmdk_path.stat().st_size:
            problems.append(f"Disk {did}: file size does not match {vmdk_path.name}")
        if int(d.get(OVF + "capacity")) != gb:
            problems.append(f"Disk {did}: capacity != {gb} GiB")
    if len(files) != len(disks_expected):
        problems.append(f"{len(files)} files referenced, {len(disks_expected)} disks expected")

    items = list(root.iter(OVF + "Item"))
    ids = [i.findtext("rasd:InstanceID", namespaces=NS) for i in items]
    if len(ids) != len(set(ids)):
        problems.append(f"duplicate InstanceIDs: {ids}")
    for i in items:
        name = i.findtext("rasd:ElementName", namespaces=NS)
        parent = i.findtext("rasd:Parent", namespaces=NS)
        if parent is not None and parent not in ids:
            problems.append(f"{name}: unknown Parent {parent}")
        host = i.findtext("rasd:HostResource", namespaces=NS)
        if host is not None:
            m = re.fullmatch(r"ovf:/disk/(.+)", host)
            if not m or m.group(1) not in disks:
                problems.append(f"{name}: unknown HostResource {host}")
        conn = i.findtext("rasd:Connection", namespaces=NS)
        if conn is not None and conn not in networks:
            problems.append(f"{name}: unknown network {conn}")

    keys = [p.get(OVF + "key") for p in root.iter(OVF + "Property")]
    if len(keys) != len(set(keys)):
        problems.append(f"duplicate vApp property keys: {keys}")

    if problems:
        die("OVF checks failed:\n  " + "\n  ".join(problems))
    log(f"OVF checks ok: {len(items)} hardware items, {len(keys)} vApp properties")


def main():
    if len(sys.argv) != 4:
        die("usage: make-ova.py <template> <platform> <outdir>")
    template, platform, outdir = sys.argv[1], sys.argv[2], Path(sys.argv[3]).resolve()

    env = load_settings(template, platform)
    ovf_dir = REPO / "platforms" / platform / "ovf"
    if not (ovf_dir / "envelope.ovf.in").is_file():
        die(f"no platforms/{platform}/ovf/envelope.ovf.in")

    img = outdir / env["IMAGE_FILE"]
    swap_img = outdir / env["SWAP_IMAGE_FILE"]
    for p in (img, swap_img):
        if not p.is_file():
            die(f"no image {p}")
    ova = outdir / env["OVA_FILE"]
    base = ova.stem
    disk_gb = int(env["DISK_GB"])
    swap_gb = int(env["SWAP_GB"])
    cpus = int(env["CPUS"])
    # The OVF states the sizes from the settings; the images must match
    # (they can come from an earlier run when a release repackages them).
    for p, gb in ((img, disk_gb), (swap_img, swap_gb)):
        if p.stat().st_size != gb * 1024**3:
            die(f"{p.name} is {p.stat().st_size} bytes, the settings say {gb} GiB")

    work = Path(tempfile.mkdtemp(prefix="make-ova-", dir=outdir))
    try:
        vmdks = []
        for n, src in enumerate((img, swap_img), 1):
            vmdk = work / f"{base}-disk{n}.vmdk"
            log(f"vmdk: {src.name} -> {vmdk.name}")
            subprocess.run(["qemu-img", "convert", "-O", "vmdk",
                            "-o", "subformat=streamOptimized", str(src), str(vmdk)], check=True)
            if vmdk.stat().st_size > USTAR_MAX:
                die(f"{vmdk.name} is 8 GiB or larger; the OVA tar format can't store it")
            vmdks.append(vmdk)
        vmdk1, vmdk2 = vmdks

        values = {
            "vmdk1_file": vmdk1.name,
            "vmdk1_size": vmdk1.stat().st_size,
            "disk1_gb": disk_gb,
            # Allocated data of the sparse raw image: what the disk needs
            # when deployed thin.
            "populated1_size": img.stat().st_blocks * 512,
            "vmdk2_file": vmdk2.name,
            "vmdk2_size": vmdk2.stat().st_size,
            "disk2_gb": swap_gb,
            "populated2_size": swap_img.stat().st_blocks * 512,
            "vm_name": base,
            "cpus": cpus,
            "cores_per_socket": cpus,   # one socket
            "memory_mb": int(env["MEMORY_MB"]),
            "hw_version": env.get("HW_VERSION", ""),
            "guest_id": env.get("GUEST_ID", ""),
            "os_cim_id": env.get("OS_CIM_ID", ""),
            "default_domain": env["DEFAULT_DOMAIN"],
            "default_username": env["DEFAULT_USERNAME"],
            "default_timezone": env["DEFAULT_TIMEZONE"],
            "product_info_xml": product_info(env),
        }
        product = ovf_dir / "product-section.xml.in"
        values["product_section_xml"] = render(product, values).rstrip("\n") if product.is_file() else ""

        ovf = work / f"{base}.ovf"
        ovf.write_text(render(ovf_dir / "envelope.ovf.in", values))
        log(f"ovf: {ovf.name}")
        validate_schema(ovf)
        check_ovf(ovf, [("vmdisk1", vmdk1, disk_gb), ("vmdisk2", vmdk2, swap_gb)])

        mf = work / f"{base}.mf"
        mf.write_text("".join(f"SHA256({p.name})= {sha256(p)}\n" for p in (ovf, *vmdks)))

        # The OVF descriptor must be the first file in the archive.
        tmp_ova = work / ova.name
        with tarfile.open(tmp_ova, "w", format=tarfile.USTAR_FORMAT) as tar:
            for p in (ovf, mf, *vmdks):
                info = tar.gettarinfo(str(p), arcname=p.name)
                info.uid = info.gid = 0
                info.uname = info.gname = "root"
                info.mode = 0o644
                with open(p, "rb") as f:
                    tar.addfile(info, f)
        os.replace(tmp_ova, ova)
        (outdir / f"{ova.name}.sha256").write_text(f"{sha256(ova)}  {ova.name}\n")
        # Keep the descriptor beside the OVA for inspection.
        shutil.copy2(ovf, outdir / ovf.name)
    finally:
        shutil.rmtree(work, ignore_errors=True)

    log(f"ova: {ova} ({ova.stat().st_size / 1024**2:.0f} MiB)")
    log(f"product: {product_name(env)} {product_version(env)}")


if __name__ == "__main__":
    main()
