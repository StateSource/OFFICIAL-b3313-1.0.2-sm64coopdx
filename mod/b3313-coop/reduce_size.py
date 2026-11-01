from pathlib import Path

TEXTURES = Path(__file__).resolve().parent / "textures"
2
def show_progress(action, file):
    print(f"[{action}] {file.name}", flush=True)
def remove_pngs():
    files = list(TEXTURES.rglob("*.png"))
    for file in files:
        show_progress("DELETE", file)
        file.unlink()
    print(f"\nRemoved {len(files)} PNG file(s).")
def convert_tex_to_png():
    files = list(TEXTURES.rglob("*.tex"))
    converted = 0
    for file in files:
        target = file.with_suffix(".png")
        if target.exists():
            print(f"[SKIP] {target.name} already exists.")
            continue
        show_progress("RENAME", file)
        file.rename(target)
        converted += 1
    print(f"\nConverted {converted} TEX file(s).")
def convert_png_to_tex():
    files = list(TEXTURES.rglob("*.png"))
    converted = 0
    for file in files:
        target = file.with_suffix(".tex")
        if target.exists():
            print(f"[SKIP] {target.name} already exists.")
            continue
        show_progress("RENAME", file)
        file.rename(target)
        converted += 1
    print(f"\nConverted {converted} PNG file(s).")
if not TEXTURES.is_dir():
    print("Textures folder not found!")
else:
    print("1. Remove all PNGs")
    print("2. Convert TEX to PNG")
    print("3. Convert PNG to TEX")
    choice = input("\nSelect an operation: ")
    if choice == "1":
        remove_pngs()
    elif choice == "2":
        convert_tex_to_png()
    elif choice == "3":
        convert_png_to_tex()
    else:
        print("Invalid option.")