# Exam Answer Processing Pipeline - Guide

This folder contains two scripts that turn student exam PDFs/DOCX files
into organized, question-by-question text data.

**What the pipeline does, in plain language:**

```
Student PDF/DOCX files  ->  STEP 1  ->  Plain text files  ->  STEP 2  ->  One row per student, per question
   (exam submissions)      (convert)      (.txt files)      (split)      (a spreadsheet-friendly CSV)
```

You will run two scripts, in order, every time you have a new batch of
exams to process:

1. **`convert_exam_files_to_txt.py`** - reads every PDF and DOCX file in
   a folder you point it at, and saves each one as a plain `.txt` file.
2. **`split_text_by_main_question_updated.py`** - reads those `.txt`
   files and splits each student's answer into Q1, Q2, Q3, etc., saving
   the result as both individual files and one combined spreadsheet.

You do not need to know how to code to run this. You do need to get one
thing exactly right each time: **the folder path** you give the script.
That's covered in detail below, since it's the one step that causes
almost all first-time problems.

---

## Before you start (one-time setup)

You only need to do this section once, the very first time you use
this pipeline. After that, skip to "Running the Pipeline" below.

### 1. Check that Python is installed

Open **PowerShell** (search for it in the Windows Start menu) and type:

```
python --version
```

If you see something like `Python 3.11.4`, you're set. If you see an
error instead, you'll need to install Python from
[python.org/downloads](https://www.python.org/downloads/) first - when
installing, make sure to check the box that says **"Add Python to
PATH"**, or the commands below won't work.

### 2. Install the required packages

Still in PowerShell, copy and paste this exactly, then press Enter:

```
pip install pypdf python-docx
```

You'll see some text scroll by - that's normal. When it stops and gives
you back a normal prompt, it worked. You only need to do this once per
computer, not once per script run.

---

## Understanding Filepaths

This is the part that trips people up most, so read this section
carefully - it will save you time on every future run.

**A filepath is just the "address" of a folder or file on your
computer.** It tells the script exactly where to look. If the filepath
is even slightly wrong (a missing letter, wrong slash, wrong folder),
the script won't be able to find your files, and it will tell you so
clearly (it won't silently do the wrong thing).

### How to get the correct filepath (Windows)

1. Open **File Explorer** and navigate to the folder that contains your
   PDF/DOCX exam files.
2. Click once on the **address bar** at the top of the window (the bar
   that shows where you currently are - clicking it turns the folder
   "breadcrumbs" into plain text).
3. The full path is now selected/highlighted. Press **Ctrl+C** to copy it.
4. It will look something like:
   ```
   C:\Users\iraa\Downloads\MGHC23_Exam_Files
   ```

### Putting the filepath into the script

Open `convert_exam_files_to_txt.py` in any text editor (Notepad works
fine - right-click the file -> "Open with" -> Notepad). Near the top,
you'll see this:

```python
INPUT_FOLDER = r"PASTE_YOUR_FOLDER_PATH_HERE"
```

Replace the placeholder text with your copied path, **keeping the
quotation marks and the `r` right before them**:

```python
INPUT_FOLDER = r"C:\Users\name\Downloads\MGHC23_Exam_Files"
```

The `r` before the quotes is important - don't remove it. It tells
Python "treat backslashes as normal characters," which Windows paths
need. Without it, you may see confusing errors about the path.

Save the file (Ctrl+S) after editing. That's it - the path only needs
to be updated when you're pointing at a *different* folder of files
than last time.

### Common filepath mistakes

| Mistake | What happens | Fix |
|---|---|---|
| Forgot the `r` before the quotes | Confusing error about escape characters | Add `r"..."` not just `"..."` |
| Deleted the quotation marks | Script won't run at all (syntax error) | Path must be inside `" "` |
| Copied the path to a *file* instead of the *folder* | "Folder not found" error | Click into the folder first, then copy the address bar |
| Path has a typo | "Folder not found" error, with the exact wrong path printed so you can compare | Re-copy from File Explorer rather than typing by hand |
| Files are inside a sub-folder of the one you pointed at | Script runs but says "No .pdf or .docx files were found" | Point directly at the folder containing the files, not a parent folder |

If you ever get a "Folder not found" message, the script will print out
exactly what path it tried to use - compare that against your File
Explorer address bar to spot the difference.

---

## Running the Pipeline

### Step 1: Convert PDF/DOCX files to text

1. Put all the student PDF/DOCX exam files into one folder (any name,
   any location - that's the folder you'll point `INPUT_FOLDER` at).
2. Edit `INPUT_FOLDER` in `convert_exam_files_to_txt.py` as described
   above.
3. In PowerShell, navigate to the folder containing the script. For
   example:
   ```
   cd C:\Users\name\Documents\MGHC23_pipeline
   ```
4. Run the script:
   ```
   python convert_exam_files_to_txt.py
   ```
5. Watch the output. You'll see each file being converted, then a
   summary like:
   ```
   Converted successfully:       22
   Converted with a warning:     1  (check these)
   Failed (not converted at all): 0
   ```

**What "with a warning" means:** almost always, this means the PDF is a
*scanned image* (someone photographed or scanned a handwritten page)
rather than real text. The script can't pull text out of a picture - it
needs OCR software for that, which this pipeline doesn't include. If
you see this, note the file rather than trying to fix it
yourself.

A new folder called **`txt_output`** will appear automatically,
containing one `.txt` file per student. You don't need to open or edit
these - they're just the input for Step 2.

### Step 2: Split each student's answer by question

1. Run:
   ```
   python split_text_by_main_question_updated.py
   ```
2. This automatically reads from the `txt_output` folder Step 1 just
   created - you don't need to set a filepath for this one, as long as
   Step 1 ran in the same folder.
3. You'll see each student's file processed, listing which questions
   (Q1, Q2, etc.) were found in their answer.

A new folder called **`split_by_main_question`** will appear, containing:

- One `.json` file per student (a per-student breakdown - you likely
  won't need to open these directly).
- **`all_students_main_questions.csv`** - the main output. One row per
  student, per question. This opens directly in Excel and is what
  feeds into the rest of the analysis (comparing exam answers to
  reflection journals).

---

## Checking Your Results

Before moving on to any further analysis, open
`all_students_main_questions.csv` in Excel and sanity-check it:

- Does the number of unique student files roughly match the number of
  exams you started with?
- Does each student have rows for Q1 through Q7 (or however many
  questions the exam had)? If a student is missing several questions,
  open their original PDF/DOCX and check whether they numbered their
  answers unusually (e.g., wrote "Question One" spelled out, or used
  a format the script doesn't recognize) - see Troubleshooting below.

---

## Troubleshooting

**"MISSING PYTHON PACKAGES" when running Step 1**
You skipped or need to redo the one-time setup. Run the `pip install`
command from the "Before you start" section above.

**"FOLDER NOT FOUND"**
See "Understanding Filepaths" above. The exact path the script tried is
printed for you to compare against File Explorer.

**"No .pdf or .docx files were found"**
The folder path is correct, but the script found no PDF/DOCX files
directly inside it. Check they aren't inside a further sub-folder.

**A student's answers all end up under Q1 (or are missing later
questions)**
This usually means the script didn't recognize how that student
numbered their answers (for example, if they only wrote "1", "2", "3"
with no punctuation, or skipped a question number). This is a known
limitation, not a bug - note these specific students separately rather
than trying to adjust the script's pattern-matching yourself, since
loosening it risks incorrectly splitting *other* students' numbered
lists into false questions.

**Something else looks wrong**
Don't try to edit the scripts to fix it - the pattern-matching logic in
Step 2 in particular is deliberately conservative to avoid silent
mistakes. Keep a note of the exact error message (or a screenshot) plus
the specific student file it happened on, so it can be looked into.
