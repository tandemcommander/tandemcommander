"""Feature 349: copies of mkimg349.sh's ISO 9660 + HFS+ hybrid whose HFS+ catalog holds folders moved
into other folders, as macOS leaves them after a folder made first is moved into a newer one: the moved
folder keeps its own catalog ID, lower than its new parent's, so the records of its contents (keyed by
its ID) come before its own record (keyed by the new parent's ID) in the catalog's order.

  python -I img349.py dump <src>                  the leaf records in catalog order
  python -I img349.py move <src> <dst> <c>:<p>... a copy; each folder <c> moved into the folder <p>, in
                                                  the order given; a folder is a path from the HFS+ root
                                                  of '/'-separated name prefixes, each matching one
                                                  folder (a, b, c, k, n1/n2/n3/n4)
  python -I img349.py cycle <src> <dst> <x>:<y>   a copy; folders <x> and <y> each made the other's
                                                  parent (a damaged catalog: neither reaches the root)

A move changes the moved folder's key (parent ID), its thread record's parent ID and the valences of
the old and the new parent, then sorts the leaf records again by (parent ID, name) as HFS+ keeps them
(TN1150; names compared without case - the names here are ASCII) and lays them into the same leaf nodes
anew (a tree of depth 2: the index node's keys too). Every folder named must have a lower catalog ID
than its new parent (else the move would not change the order and the script stops). The catalog must
be one extent.
Prints what it wrote.
"""

import struct
import sys


def be16(b, o):
    return struct.unpack_from(">H", b, o)[0]


def be32(b, o):
    return struct.unpack_from(">I", b, o)[0]


def find_vh(img):
    for o in range(1024, len(img) - 512, 512):
        if img[o : o + 4] == b"H+\x00\x04":
            return o
    raise SystemExit("no HFS+ volume header")


def catalog(img):
    vh = find_vh(img)
    vol = vh - 1024
    block = be32(img, vh + 40)
    fork = vh + 272
    size = struct.unpack_from(">Q", img, fork)[0]
    start, count = be32(img, fork + 16), be32(img, fork + 20)
    if count * block < size:
        raise SystemExit("the catalog has more than one extent")
    base = vol + start * block
    return base, be16(img, base + 14 + 18), be32(img, base + 14 + 10)


def node_records(img, p, ns):
    n = be16(img, p + 10)
    offs = [be16(img, p + ns - 2 * (i + 1)) for i in range(n + 1)]  # the last = free space start
    return [bytes(img[p + offs[i] : p + offs[i + 1]]) for i in range(n)]


def leaf(img):
    """(catalog base, node size, [leaf node numbers], [record bytes of all leaves in order])"""
    base, ns, node = catalog(img)
    nodes, recs = [], []
    while node:
        p = base + node * ns
        nodes.append(node)
        recs += node_records(img, p, ns)
        node = be32(img, p)
    return base, ns, nodes, recs


def parse(r):
    klen = be16(r, 0)
    nlen = be16(r, 6)
    body = 2 + klen
    t = be16(r, body)
    d = dict(parent=be32(r, 2), name=r[8 : 8 + 2 * nlen].decode("utf-16-be", "replace"), type=t, body=body)
    if t == 1:
        d["id"] = be32(r, body + 8)
        d["valence"] = be32(r, body + 4)
    elif t in (3, 4):
        d["tparent"] = be32(r, body + 4)
    return d


def show(recs):
    for r in recs:
        d = parse(r)
        kind = {1: "folder", 2: "file", 3: "folder-thread", 4: "file-thread"}.get(d["type"], "type %d" % d["type"])
        extra = ""
        if d["type"] == 1:
            extra = " id %d valence %d" % (d["id"], d["valence"])
        elif d["type"] in (3, 4):
            extra = " -> parent %d" % d["tparent"]
        nm = d["name"] if len(d["name"]) < 12 else d["name"][:3] + "..(%d)" % len(d["name"])
        print("key parent %3d %-14s %s%s" % (d["parent"], ascii(nm), kind, extra))


def root_folder(recs, path):
    parent, hit = 2, None
    for prefix in path.split("/"):
        hits = [r for r in recs if parse(r)["type"] == 1 and parse(r)["parent"] == parent and parse(r)["name"].startswith(prefix)]
        if len(hits) != 1:
            raise SystemExit("folder %r of %r not found once: %d" % (prefix, path, len(hits)))
        hit = hits[0]
        parent = parse(hit)["id"]
    return hit


def set_key_parent(r, parent):
    return r[:2] + struct.pack(">I", parent) + r[6:]


def set_valence(recs, fid, delta):
    for i, r in enumerate(recs):
        d = parse(r)
        if d["type"] == 1 and d["id"] == fid:
            b = d["body"]
            recs[i] = r[: b + 4] + struct.pack(">I", d["valence"] + delta) + r[b + 8 :]
            return
    if fid != 1:
        raise SystemExit("no folder record of id %d" % fid)


def reparent(recs, child_rec, new_parent):
    """the folder record child_rec moved under new_parent (its key and its thread record)"""
    d = parse(child_rec)
    cid, old = d["id"], d["parent"]
    out = []
    for r in recs:
        e = parse(r)
        if r == child_rec:
            r = set_key_parent(r, new_parent)
        elif e["type"] == 3 and e["parent"] == cid:
            b = e["body"]
            r = r[: b + 4] + struct.pack(">I", new_parent) + r[b + 8 :]
        out.append(r)
    set_valence(out, old, -1)
    set_valence(out, new_parent, +1)
    return out


def pack_node(img, p, ns, recs):
    node = bytearray(img[p : p + 14]) + bytearray(ns - 14)
    struct.pack_into(">H", node, 10, len(recs))
    off = 14
    for i, r in enumerate(recs):
        node[off : off + len(r)] = r
        struct.pack_into(">H", node, ns - 2 * (i + 1), off)
        off += len(r)
    if off > ns - 2 * (len(recs) + 1):
        raise SystemExit("the records do not fit the node")
    struct.pack_into(">H", node, ns - 2 * (len(recs) + 1), off)
    img[p : p + ns] = node


def write_leaves(img, base, ns, nodes, recs):
    """the records sorted again and laid into the same leaf nodes in order, each filled while they fit;
    a tree of depth 2 gets its index node's keys (the first key of each leaf) written anew"""
    recs.sort(key=lambda r: (parse(r)["parent"], parse(r)["name"].lower()))
    parts, cur, used = [], [], 14
    for r in recs:
        if used + len(r) + 2 * (len(cur) + 2) > ns:
            parts.append(cur)
            cur, used = [], 14
        cur.append(r)
        used += len(r)
    parts.append(cur)
    if len(parts) > len(nodes):
        raise SystemExit("the records need more leaf nodes than the catalog has")
    parts += [[] for _ in range(len(nodes) - len(parts))]
    if any(not part for part in parts):
        raise SystemExit("a leaf node would be empty")
    for node, part in zip(nodes, parts):
        pack_node(img, base + node * ns, ns, part)
    depth, root = be16(img, base + 14), be32(img, base + 16)
    if len(nodes) > 1:
        if depth != 2:
            raise SystemExit("a tree of depth %d" % depth)
        index = []
        for node, part in zip(nodes, parts):
            k = part[0][: 2 + be16(part[0], 0)]
            index.append(k + struct.pack(">I", node))
        pack_node(img, base + root * ns, ns, index)


def main(argv):
    if len(argv) == 3 and argv[1] == "dump":
        show(leaf(open(argv[2], "rb").read())[3])
        return 0
    if len(argv) < 5 or argv[1] not in ("move", "cycle"):
        print(__doc__)
        return 2
    how, src, dst = argv[1:4]
    img = bytearray(open(src, "rb").read())
    base, ns, nodes, recs = leaf(img)
    for pair in argv[4:]:
        c, par = pair.split(":")
        cr, pr = root_folder(recs, c), root_folder(recs, par)
        cid, pid = parse(cr)["id"], parse(pr)["id"]
        if cid >= pid:
            raise SystemExit("%s (id %d) is not lower than %s (id %d)" % (c, cid, par, pid))
        if how == "move":
            recs = reparent(recs, cr, pid)
            print("move: %s (id %d) into %s (id %d)" % (c, cid, par, pid))
        else:
            recs = reparent(recs, cr, pid)
            pr = root_folder(recs, par)
            recs = reparent(recs, pr, cid)
            print("cycle: %s (id %d) and %s (id %d) each the other's parent" % (c, cid, par, pid))
    write_leaves(img, base, ns, nodes, recs)
    open(dst, "wb").write(bytes(img))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
