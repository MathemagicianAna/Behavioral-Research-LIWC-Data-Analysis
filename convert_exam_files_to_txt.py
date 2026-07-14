"""
convert_exam_files_to_txt.py

STEP 1 of 2 in the exam-processing pipeline.

Converts student exam submissions (PDF and DOCX files) into plain .txt
files, one .txt file per submission, saved into a "txt_output" folder.
Those .txt files are what split_text_by_main_question_updated.py
(STEP 2) reads and splits into Q1, Q2, Q3, etc.

WHAT THIS SCRIPT DOES:
    1. Looks inside the folder you specify below (INPUT_FOLDER).
    2. Reads every .pdf and .docx file in that folder.
    3. Extracts the text from each file.
    4. Saves the text as a new .txt file with the same name, into OUTPUT_FOLDER.
    5. Prints a summary at the end: how many files worked, how many had
       warnings, and how many failed - and why.

BEFORE YOU RUN THIS:
    See README.md for full setup instructions (installing Python
    packages, understanding filepaths, etc). This comment block is a
    quick reminder, not a substitute for the README.

SETTINGS: edit INPUT_FOLDER below, then run the script.
"""

from pathlib import Path
import sys

# =========================
# SETTINGS - edit this line
# =========================
# The folder that contains the PDF and DOCX files you want to convert.
# See README.md, section "Understanding Filepaths", if you're not sure
# how to find and copy this.
INPUT_FOLDER = r"PASTE_YOUR_FOLDER_PATH_HERE"

# Where the converted .txt files will be saved. This is created
# automatically - you do NOT need to make this folder yourself, and you
# should not need to change this name (STEP 2 looks for this exact name).
OUTPUT_FOLDER = "txt_output"


# =========================
# Everything below this line runs automatically.
# You should not need to edit anything below this line.
# =========================

REQUIRED_PACKAGES = {"pypdf": "pypdf", "docx": "python-docx"}


def check_packages():
    missing = []
    for import_name, pip_name in REQUIRED_PACKAGES.items():
        try:
            __import__(import_name)
        except ImportError:
            missing.append(pip_name)
    if missing:
        print("=" * 70)
        print("MISSING PYTHON PACKAGES")
        print("=" * 70)
        print("This script needs the following package(s) installed first:")
        for pkg in missing:
            print(f"  - {pkg}")
        print()
        print("To install them, open PowerShell (or Command Prompt) and run:")
        print(f"    pip install {' '.join(missing)}")
        print()
        print("Then run this script again.")
        print("=" * 70)
        sys.exit(1)


check_packages()

from pypdf import PdfReader
import docx


def extract_pdf_text(path: Path):
    """Returns (text, warning). warning is None if extraction looked normal."""
    reader = PdfReader(str(path))
    pages_text = []
    for i, page in enumerate(reader.pages, start=1):
        page_text = page.extract_text() or ""
        # "--- Page N ---" markers match what split_text_by_main_question_updated.py
        # expects and automatically skips - keep this format exactly.
        pages_text.append(f"--- Page {i} ---\n{page_text}")
    full_text = "\n".join(pages_text)

    warning = None
    if len(full_text.replace("---", "").strip()) < 20:
        warning = (
            "Almost no text was found in this PDF. This usually means the "
            "PDF is a SCANNED IMAGE (a photo or scan of the page) rather "
            "than real text, and needs OCR software before it can be "
            "processed here. See README.md, 'Troubleshooting'."
        )
    return full_text, warning


def extract_docx_text(path: Path):
    document = docx.Document(str(path))
    paragraphs = [p.text for p in document.paragraphs]
    full_text = "\n".join(paragraphs)

    warning = None
    if len(full_text.strip()) < 20:
        warning = (
            "Almost no text was found in this DOCX file. Please open it "
            "manually to check it isn't blank, password-protected, or "
            "corrupted."
        )
    return full_text, warning


def convert_folder(input_folder: str, output_folder: str) -> None:
    input_dir = Path(input_folder)
    output_dir = Path(output_folder)

    if not input_dir.exists():
        print("=" * 70)
        print("FOLDER NOT FOUND")
        print("=" * 70)
        print(f"This filepath does not exist:\n    {input_dir}")
        print()
        print("Double check INPUT_FOLDER at the top of this script.")
        print("See README.md, 'Understanding Filepaths', for how to find")
        print("and copy the correct folder path.")
        print("=" * 70)
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    pdf_files = sorted(input_dir.glob("*.pdf"))
    docx_files = sorted(input_dir.glob("*.docx"))
    all_files = pdf_files + docx_files

    if not all_files:
        print(f"No .pdf or .docx files were found in:\n    {input_dir}")
        print("Double check the folder path, and that the files are directly")
        print("inside it (not inside a sub-folder).")
        return

    print(f"Found {len(pdf_files)} PDF file(s) and {len(docx_files)} DOCX file(s).")
    print(f"Saving converted .txt files to:\n    {output_dir.resolve()}\n")

    succeeded, warned, failed = [], [], []

    for file_path in all_files:
        print(f"Converting: {file_path.name} ...", end=" ")
        try:
            if file_path.suffix.lower() == ".pdf":
                text, warning = extract_pdf_text(file_path)
            else:
                text, warning = extract_docx_text(file_path)

            out_path = output_dir / f"{file_path.stem}.txt"
            out_path.write_text(text, encoding="utf-8")

            if warning:
                print("done, but with a warning")
                warned.append((file_path.name, warning))
            else:
                print("done")
                succeeded.append(file_path.name)

        except Exception as e:
            print("FAILED")
            failed.append((file_path.name, str(e)))

    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Converted successfully:       {len(succeeded)}")
    print(f"Converted with a warning:     {len(warned)}  (check these)")
    print(f"Failed (not converted at all): {len(failed)}")

    if warned:
        print("\nFiles with warnings:")
        for name, msg in warned:
            print(f"  - {name}")
            print(f"      {msg}")

    if failed:
        print("\nFiles that failed:")
        for name, msg in failed:
            print(f"  - {name}")
            print(f"      Error: {msg}")

    print("\nDone. Next step: run split_text_by_main_question_updated.py")
    print("(see README.md, Step 2).")


if __name__ == "__main__":
    convert_folder(INPUT_FOLDER, OUTPUT_FOLDER)
