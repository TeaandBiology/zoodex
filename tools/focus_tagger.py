#!/usr/bin/env python3
"""
ZooDex image tagger
===================

A small desktop tool for framing species photos and recording image copyright.

For each image in the project's images/ folder you can:
  * click a focus point — the spot that must stay visible when the app crops the
    photo to the square grid tile or the tall species-page hero;
  * type the image copyright/attribution (auto-filled from
    tools/reports/image_credits.csv when the downloader has a row);
  * import a new photo (any format) and have it converted to images/<slug>.webp.

It writes two files the app reads:
  assets/data/image_focus.json    {"focus":   {slug: [x, y]}}   x,y in 0..1
  assets/data/image_credits.json  {"credits": {slug: "..."}}

Run:   python tools/focus_tagger.py [project_root]
(project_root defaults to the current directory)

Build a double-clickable .exe (optional):
    pip install pyinstaller pillow
    pyinstaller --onefile --windowed tools/focus_tagger.py
The .exe lands in dist/. Run it from your project root (or pass the root when
prompted) so it can find images/ and assets/data/.
"""

import json
import os
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("This tool needs Pillow:  pip install pillow")

PLACEHOLDER_PREFIX = "default"
IMG_EXTS = (".webp", ".png", ".jpg", ".jpeg")


# --------------------------------------------------------------------------- #
# Pure helpers (no GUI) — unit-testable
# --------------------------------------------------------------------------- #
def project_paths(root: Path):
    return {
        "images": root / "images",
        "focus": root / "assets" / "data" / "image_focus.json",
        "credits": root / "assets" / "data" / "image_credits.json",
        "catalog": root / "assets" / "data" / "species_catalog.json",
        "reports": root / "tools" / "reports",
    }


def list_image_slugs(images_dir: Path):
    """Slugs (filename stems) of real photos in images/, excluding placeholders."""
    out = {}
    if not images_dir.is_dir():
        return out
    for p in sorted(images_dir.iterdir()):
        if p.suffix.lower() not in IMG_EXTS:
            continue
        if p.name.lower().startswith(PLACEHOLDER_PREFIX):
            continue
        out.setdefault(p.stem, p)  # first match wins (.webp before .png alphabetically? ensure webp pref)
    return out


def load_map(path: Path, key: str):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        inner = data.get(key, data) if isinstance(data, dict) else {}
        return dict(inner) if isinstance(inner, dict) else {}
    except Exception:
        return {}


def save_map(path: Path, key: str, mapping: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps({key: mapping}, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )


def load_common_names(catalog_path: Path):
    try:
        cat = json.loads(catalog_path.read_text(encoding="utf-8"))
        return {s.get("slug"): s.get("common_name", "") for s in cat}
    except Exception:
        return {}


def compose_credit(row: dict) -> str:
    """Build a copyright string from a credits row. The downloader's
    `attribution` field is already a full human-readable credit; if it's blank,
    fall back to source / licence / url."""
    attr = (row.get("attribution") or "").strip()
    if attr:
        return attr
    src = (row.get("source") or "").strip()
    lic = (row.get("license") or "").strip()
    url = (row.get("source_url") or "").strip()
    bits = [b for b in [src, lic.upper() if lic else "", url] if b]
    return " — ".join(bits)


def _read_csv_credits(path: Path) -> dict:
    import csv
    out = {}
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            slug = (row.get("slug") or "").strip()
            if slug:
                out[slug] = compose_credit({(k or "").lower(): v for k, v in row.items()})
    return out


def _read_xlsx_credits(path: Path) -> dict:
    from openpyxl import load_workbook
    wb = load_workbook(path, read_only=True, data_only=True)
    ws = wb.active
    rows = ws.iter_rows(values_only=True)
    header = [str(c).strip().lower() if c is not None else "" for c in next(rows)]
    idx = {name: i for i, name in enumerate(header) if name}
    out = {}
    for r in rows:
        def g(col):
            i = idx.get(col)
            return "" if i is None or i >= len(r) or r[i] is None else str(r[i])
        slug = g("slug").strip()
        if slug:
            out[slug] = compose_credit({h: g(h) for h in idx})
    wb.close()
    return out


def load_credit_suggestions(reports_dir: Path) -> dict:
    """slug -> suggested copyright string, from tools/reports.
    Prefers image_credits.xlsx (e.g. one you've edited in Excel), else the
    image_credits.csv the downloader emits. Never fatal."""
    xlsx = reports_dir / "image_credits.xlsx"
    csvf = reports_dir / "image_credits.csv"
    if xlsx.exists():
        try:
            return _read_xlsx_credits(xlsx)
        except ImportError:
            print("image_credits.xlsx found but openpyxl isn't installed "
                  "(pip install openpyxl); falling back to the .csv.")
        except Exception as e:
            print(f"Couldn't read image_credits.xlsx ({e}); falling back to .csv.")
    if csvf.exists():
        try:
            return _read_csv_credits(csvf)
        except Exception as e:
            print(f"Couldn't read image_credits.csv ({e}).")
    return {}


def cover_crop(img: "Image.Image", tw: int, th: int, fx: float, fy: float):
    """Crop `img` to a tw:th box using cover semantics, framed around the focal
    point (fx, fy in 0..1). Mirrors Flutter BoxFit.cover + Alignment so the
    preview matches the app."""
    iw, ih = img.size
    scale = max(tw / iw, th / ih)
    cw, ch = tw / scale, th / scale
    cx, cy = fx * iw, fy * ih
    left = min(max(cx - cw / 2, 0), iw - cw)
    top = min(max(cy - ch / 2, 0), ih - ch)
    box = (round(left), round(top), round(left + cw), round(top + ch))
    return img.crop(box).resize((tw, th), Image.LANCZOS)


def slugify(name: str) -> str:
    keep = []
    for ch in name.strip().lower():
        if ch.isalnum():
            keep.append(ch)
        elif ch in " -_":
            keep.append("_")
    s = "".join(keep)
    while "__" in s:
        s = s.replace("__", "_")
    return s.strip("_")


def import_image(src: Path, slug: str, images_dir: Path,
                 max_dim: int = 1024, quality: int = 85) -> Path:
    """Copy/convert an arbitrary image into images/<slug>.webp."""
    images_dir.mkdir(parents=True, exist_ok=True)
    im = Image.open(src).convert("RGB")
    w, h = im.size
    if max(w, h) > max_dim:
        s = max_dim / max(w, h)
        im = im.resize((round(w * s), round(h * s)), Image.LANCZOS)
    dest = images_dir / f"{slug}.webp"
    im.save(dest, "WEBP", quality=quality, method=6)
    return dest


# --------------------------------------------------------------------------- #
# GUI
# --------------------------------------------------------------------------- #
def run_gui(root_dir: Path):
    import tkinter as tk
    from tkinter import filedialog, messagebox, simpledialog
    from PIL import ImageTk, ImageDraw

    paths = project_paths(root_dir)
    focus = load_map(paths["focus"], "focus")
    credits = load_map(paths["credits"], "credits")
    names = load_common_names(paths["catalog"])
    suggestions = load_credit_suggestions(paths["reports"])

    def reload_slugs():
        return list_image_slugs(paths["images"])

    slug_files = reload_slugs()
    slugs = sorted(slug_files)

    app = tk.Tk()
    app.title(f"ZooDex image tagger — {root_dir}")
    app.geometry("1024x640")

    state = {"slug": None, "img": None, "tkmain": None,
             "main_box": (0, 0, 1, 1), "preview_refs": []}

    # ---- layout ----
    left = tk.Frame(app, width=220)
    left.pack(side="left", fill="y")
    tk.Label(left, text="Images").pack(anchor="w", padx=6, pady=(6, 0))
    listbox = tk.Listbox(left, width=34)
    listbox.pack(fill="y", expand=True, padx=6, pady=6)

    center = tk.Frame(app)
    center.pack(side="left", fill="both", expand=True)
    canvas = tk.Canvas(center, bg="#222", highlightthickness=0)
    canvas.pack(fill="both", expand=True, padx=8, pady=8)
    hint = tk.Label(center, text="Click the photo to set the focus point")
    hint.pack()

    right = tk.Frame(app, width=300)
    right.pack(side="left", fill="y")
    tk.Label(right, text="How the app will crop it").pack(anchor="w", padx=8, pady=(8, 0))
    prev_row = tk.Frame(right)
    prev_row.pack(padx=8, pady=4)
    preview_specs = [("Grid 1:1", 120, 120), ("Hero phone", 120, 160), ("Hero wide", 200, 112)]
    preview_canvases = []
    for label, pw, ph in preview_specs:
        col = tk.Frame(prev_row)
        col.pack(side="left", padx=4)
        c = tk.Canvas(col, width=pw, height=ph, bg="#333", highlightthickness=0)
        c.pack()
        tk.Label(col, text=label, font=("", 8)).pack()
        preview_canvases.append((c, pw, ph))

    tk.Label(right, text="Copyright / attribution").pack(anchor="w", padx=8, pady=(10, 0))
    credit_var = tk.StringVar()
    credit_entry = tk.Entry(right, textvariable=credit_var, width=40)
    credit_entry.pack(padx=8, pady=4, fill="x")
    suggest_note = tk.Label(right, text="", fg="#a60", anchor="w",
                            justify="left", wraplength=280, font=("", 8))
    suggest_note.pack(anchor="w", padx=8)

    status = tk.Label(right, text="", fg="#080", anchor="w", justify="left")
    status.pack(anchor="w", padx=8, pady=6, fill="x")

    def list_label(slug):
        mark = "•" if slug in focus else "  "
        cm = "©" if credits.get(slug) else ("·" if slug in suggestions else " ")
        nm = names.get(slug, "")
        return f"{mark}{cm} {slug}" + (f"  ({nm})" if nm else "")

    def refresh_list(select=None):
        listbox.delete(0, "end")
        for sl in slugs:
            listbox.insert("end", list_label(sl))
        if select in slugs:
            i = slugs.index(select)
            listbox.selection_clear(0, "end")
            listbox.selection_set(i)
            listbox.see(i)

    def draw_previews():
        state["preview_refs"].clear()
        img = state["img"]
        if img is None:
            return
        fx, fy = focus.get(state["slug"], [0.5, 0.5])
        for c, pw, ph in preview_canvases:
            crop = cover_crop(img, pw, ph, fx, fy)
            tkimg = ImageTk.PhotoImage(crop)
            c.delete("all")
            c.create_image(pw // 2, ph // 2, image=tkimg)
            state["preview_refs"].append(tkimg)

    def draw_main():
        img = state["img"]
        canvas.delete("all")
        if img is None:
            return
        cw = max(canvas.winfo_width(), 50)
        ch = max(canvas.winfo_height(), 50)
        iw, ih = img.size
        scale = min(cw / iw, ch / ih)
        dw, dh = int(iw * scale), int(ih * scale)
        ox, oy = (cw - dw) // 2, (ch - dh) // 2
        disp = img.convert("RGBA").resize((dw, dh), Image.LANCZOS)
        # draw focus crosshair
        fx, fy = focus.get(state["slug"], [0.5, 0.5])
        d = ImageDraw.Draw(disp)
        px, py = int(fx * dw), int(fy * dh)
        d.line([(px - 12, py), (px + 12, py)], fill=(255, 80, 80, 255), width=2)
        d.line([(px, py - 12), (px, py + 12)], fill=(255, 80, 80, 255), width=2)
        d.ellipse([px - 7, py - 7, px + 7, py + 7], outline=(255, 80, 80, 255), width=2)
        tkimg = ImageTk.PhotoImage(disp)
        state["tkmain"] = tkimg
        state["main_box"] = (ox, oy, dw, dh)
        canvas.create_image(ox, oy, image=tkimg, anchor="nw")

    def load_slug(slug):
        state["slug"] = slug
        try:
            state["img"] = Image.open(slug_files[slug]).convert("RGB")
        except Exception as e:
            state["img"] = None
            messagebox.showerror("Open failed", f"{slug}: {e}")
            return
        saved = credits.get(slug, "")
        if saved:
            credit_var.set(saved)
            status.config(text="")
        elif slug in suggestions:
            credit_var.set(suggestions[slug])
            status.config(text="Copyright pre-filled from image_credits.csv — "
                               "edit, then Save to keep")
        else:
            credit_var.set("")
            status.config(text="")
        draw_main()
        draw_previews()

    def on_canvas_click(ev):
        if state["img"] is None:
            return
        ox, oy, dw, dh = state["main_box"]
        if dw == 0 or dh == 0:
            return
        fx = min(max((ev.x - ox) / dw, 0.0), 1.0)
        fy = min(max((ev.y - oy) / dh, 0.0), 1.0)
        focus[state["slug"]] = [round(fx, 4), round(fy, 4)]
        draw_main()
        draw_previews()
        refresh_list(select=state["slug"])

    def on_select(_ev=None):
        sel = listbox.curselection()
        if not sel:
            return
        # commit the visible credit before switching
        if state["slug"] is not None:
            credits[state["slug"]] = credit_var.get().strip()
            if not credits[state["slug"]]:
                credits.pop(state["slug"], None)
        load_slug(slugs[sel[0]])

    def center_focus():
        if state["slug"]:
            focus[state["slug"]] = [0.5, 0.5]
            draw_main(); draw_previews(); refresh_list(select=state["slug"])

    def save_all():
        if state["slug"] is not None:
            c = credit_var.get().strip()
            if c:
                credits[state["slug"]] = c
            else:
                credits.pop(state["slug"], None)
        save_map(paths["focus"], "focus", focus)
        save_map(paths["credits"], "credits", credits)
        status.config(text=f"Saved {len(focus)} focus point(s), "
                           f"{len(credits)} credit(s).")
        refresh_list(select=state["slug"])

    def import_new():
        src = filedialog.askopenfilename(
            title="Choose an image to import",
            filetypes=[("Images", "*.png *.jpg *.jpeg *.webp *.bmp *.gif")])
        if not src:
            return
        default = slugify(Path(src).stem)
        slug = simpledialog.askstring(
            "Slug", "Species slug (matches species_catalog 'slug'):",
            initialvalue=default)
        if not slug:
            return
        slug = slugify(slug)
        try:
            import_image(Path(src), slug, paths["images"])
        except Exception as e:
            messagebox.showerror("Import failed", str(e))
            return
        nonlocal slug_files, slugs
        slug_files = reload_slugs()
        slugs = sorted(slug_files)
        refresh_list(select=slug)
        load_slug(slug)
        status.config(text=f"Imported {slug}.webp — now set its focus point.")

    btns = tk.Frame(right)
    btns.pack(side="bottom", fill="x", padx=8, pady=10)
    tk.Button(btns, text="Save", command=save_all, width=10).pack(side="left")
    tk.Button(btns, text="Centre", command=center_focus).pack(side="left", padx=4)
    tk.Button(btns, text="Import…", command=import_new).pack(side="left")

    listbox.bind("<<ListboxSelect>>", on_select)
    canvas.bind("<Button-1>", on_canvas_click)
    canvas.bind("<Configure>", lambda e: draw_main())

    refresh_list()
    if slugs:
        listbox.selection_set(0)
        load_slug(slugs[0])
        if suggestions and not status.cget("text"):
            status.config(text=f"{len(suggestions)} credit(s) available from "
                               f"image_credits.csv")
    else:
        status.config(text="No images found in images/. Use Import… to add one.")

    app.mainloop()


def main():
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()
    if not (root / "images").exists() and not (root / "assets").exists():
        print(f"Warning: {root} doesn't look like the project root "
              f"(no images/ or assets/). Continuing anyway.")
    run_gui(root)


if __name__ == "__main__":
    main()
