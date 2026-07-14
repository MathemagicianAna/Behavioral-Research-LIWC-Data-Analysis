# Project Overview

This project has two separate pipelines that work together:

1. **Exam Processing Pipeline** (Python, 2 scripts) - turns raw exam
   PDF/DOCX submissions into a spreadsheet of answers organized by
   question number.
2. **LIWC Analysis** (R, 1 script) - combines LIWC data files from the
   reflection journals, computes summary scores, runs statistical
   tests, and produces graphs.

These two pipelines are not directly connected by any script. In
between them sits one manual step: running the split exam answers (or
the reflection journal text) through the LIWC-22 software itself, which
is a separate licensed program, not something included here. That step
produces the LIWC CSV files that the R script expects as input. A
scaffold for comparing the two datasets once that connection exists
lives inside the R script itself (section 9, commented out).

This document is a map of everything - what each file does, and
critically, **where each script expects its files to live**, since this
is different between the two pipelines and is the most common source of
"it can't find my files" problems.

---

## All files at a glance

| File | Type | Purpose | Detailed guide |
|---|---|---|---|
| `convert_exam_files_to_txt.py` | Python | Step 1: converts exam PDF/DOCX files into plain `.txt` files | `README.md` (exam pipeline) |
| `split_text_by_main_question_updated.py` | Python | Step 2: splits each student's `.txt` file into Q1, Q2, Q3, etc. and combines everyone into one CSV | `README.md` (exam pipeline) |
| `README.md` | Documentation | Full walkthrough of the exam pipeline (setup, filepaths, running both steps, troubleshooting) | - |
| `QUICK_REFERENCE.md` | Documentation | Short reminder version of the exam pipeline steps, once you already know them | - |
| `CONVERSION_SCRIPT_GUIDE.md` | Documentation | Detailed outline for the exam pipeline steps to extract text and split by question | - |
| `R_SCRIPT_GUIDE.md` | Documentation | Full walkthrough of the R script (what each section does, how graphs are built, how to edit labels, common scenarios) | - |
| `MGHC23_LIWC_analysis_FIXED.R` | R | Combines LIWC CSV files, computes summary scores, runs statistical tests, produces all graphs | `R_SCRIPT_GUIDE.md` |

---

## Folder structure: the key difference between the two pipelines

This is the most important thing to understand before running either
pipeline. **They expect their input files to be organized differently.**

### The Python exam pipeline: input files can be anywhere

The two Python scripts do **not** need their input files to be in the
same folder as the scripts themselves. You tell the first script where
to look by editing one line (`INPUT_FOLDER`). The scripts' own outputs,
however, always appear next to the scripts, not inside the input
folder.

```
Wherever your exam PDFs/DOCX files happen to be, e.g.:
  C:/Users/you/Downloads/Fall2025_Exams/
    student1.pdf
    student2.docx
    ...
                                    (point INPUT_FOLDER at this folder)

The folder containing the scripts, e.g.:
  C:/Users/you/Documents/exam_pipeline/
    convert_exam_files_to_txt.py
    split_text_by_main_question_updated.py
    README.md
    QUICK_REFERENCE.md
    txt_output/                          <- created automatically HERE
      student1.txt
      student2.txt
    split_by_main_question/              <- created automatically HERE
      all_students_main_questions.csv
      student1_main_questions.json
      ...
```

Note that `txt_output` and `split_by_main_question` appear next to the
scripts, **not** inside the exam PDF folder. This is because both
folder names are relative paths, which R and Python both resolve
relative to wherever the script itself is being run from.

### The R script: everything lives together, in one folder

The R script is written with the assumption that the script and its
input CSV files sit **in the same folder**. Its own output folder is
then created as a sub-folder inside that same shared folder, not next
to anything else.

```
One folder, everything together, e.g.:
  C:/Users/you/Downloads/MGT-C23_LIWCs_Rscript/
    MGHC23_LIWC_analysis_FIXED.R
    R_SCRIPT_GUIDE.md
    LIWC_Cultural_Circle_Journal.csv
    LIWC_Reflection_on_IAM_Pie_Chart.csv
    LIWC_Sexual_Privilege_Journal.csv
    LIWC_Privilege_Exercises_Journal.csv
    LIWC_University_Case_Journal.csv
    MGHC23_LIWC_outputs/                 <- created automatically INSIDE this folder
      01_dataset_coverage.png
      02_normalized_z_score_heatmap.png
      ...
      MGHC23_LIWC_summary_tables.xlsx
```

The `input_dir` setting at the top of the R script is what points at
this folder. It's technically possible to point `input_dir` at a
different folder than the one the script itself lives in, but the
script was written and tested around the same-folder setup shown above,
so that's the recommended structure unless there's a specific reason to
change it.

### Side-by-side comparison

| | Python exam pipeline | R LIWC script |
|---|---|---|
| Where do input files need to be? | Anywhere - point `INPUT_FOLDER` at them | Same folder as the script |
| Where do the scripts need to be, relative to each other? | Both Python scripts together, in one folder | Just the one R script |
| Where do outputs appear? | Next to the scripts (not inside the input folder) | Inside the input folder, as a sub-folder |
| What you edit to point it at your files | `INPUT_FOLDER` at the top of `convert_exam_files_to_txt.py` | `input_dir` at the top of the R script |
| Filepath style | `r"C:\Users\you\..."` - backslashes are fine because of the `r` prefix | `"C:/Users/you/..."` - forward slashes only |

---

## How the two pipelines connect

There's a manual step in between them that isn't scripted:

```
Exam PDFs/DOCX
     |
     v (Python: convert_exam_files_to_txt.py)
Plain .txt files
     |
     v (Python: split_text_by_main_question_updated.py)
all_students_main_questions.csv  (one row per student, per question)
     |
     v  <-- MANUAL STEP: run this text through the LIWC-22 program
LIWC CSV files (Filename, WC, Analytic, Clout, Cognition, ...)
     |
     v (R: MGHC23_LIWC_analysis_FIXED.R)
Summary tables + graphs
```

The reflection journal LIWC files (Cultural Circle, IAM Pie Chart,
Sexual Privilege, Privilege Exercises, University Case) follow the same
manual LIWC-22 step, just starting from the journal submissions instead
of exam answers.

The commented-out section near the end of the R script (section 9) is
where exam-question scores and journal scores eventually get compared,
once both sides of that pipeline exist for the same group of students.
See `R_SCRIPT_GUIDE.md`, "Using the exam question comparison section,"
for how to activate it.

---

## Where to go next

- Setting up and running the exam pipeline for the first time: see
  `README.md`.
- Already comfortable with the exam pipeline and just need a reminder:
  see `QUICK_REFERENCE.md`.
- Understanding or editing the R script (including changing graph
  labels, adding a new LIWC file, or handling a renamed file): see
  `R_SCRIPT_GUIDE.md`.
