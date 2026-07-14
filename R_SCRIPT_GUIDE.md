# MGHC23 LIWC Analysis Script - Guide

This script reads LIWC data files (one CSV per assignment), combines
them, and produces summary tables and graphs showing how students'
writing changed across the term. This guide explains what the script
does, how the graphs get made, and how to handle the situations that
come up most often: new files being added, files being renamed, and
wanting to change what a graph says.

---

## Before you start (one-time setup)

1. Install R from [r-project.org](https://www.r-project.org/) if it
   isn't already installed.
2. Install RStudio (the program you'll actually open and run the
   script in) from
   [posit.co/download/rstudio-desktop](https://posit.co/download/rstudio-desktop/).
3. You do not need to manually install the R packages the script uses.
   The first few lines of the script check for them automatically and
   install anything missing the first time you run it. This can take a
   few minutes the very first time; after that it's fast.

---

## The one filepath you need to set

Near the top of the script, in the section labeled `2) USER SETTINGS`,
there's this line:

```r
input_dir <- "C:/Users/yourname/Downloads/MGT-C23_LIWCs_Rscript"
```

This tells the script which folder to look in for the LIWC CSV files.
**This is the only path you should normally need to change.**

A few things specific to R filepaths (these work a little differently
than in Python scripts, if you've used those too):

- Use **forward slashes** (`/`), even though this is a Windows path.
  `C:/Users/yourname/Downloads/...` works. `C:\Users\yourname\...` (with
  regular backslashes) will cause an error in R unless every backslash
  is doubled, so forward slashes are simpler - just use those.
- Keep the quotation marks around the path.
- To get the correct path: open File Explorer, navigate to the folder
  containing the LIWC CSV files and this script, click the address bar
  once to select the full path, copy it, paste it in, then swap any
  backslashes for forward slashes.

If you leave `input_dir` pointing at a folder that doesn't contain the
CSV files, the script will still run, but it will print a "Missing /
skipped files" message telling you which assignments it couldn't find
- that's your signal to double check this line.

---

## Running the script

Open the script in RStudio and click **Source** (or press Ctrl+Shift+S).
The whole script needs to run top to bottom in one go - it's not
designed to have chunks run out of order. If something partway through
errors out, fix the issue and re-run the whole thing from the top
rather than trying to continue from the middle.

When it finishes, a new folder called `MGHC23_LIWC_outputs` appears
inside your `input_dir` folder, containing the graphs (as `.png` image
files), several `.csv` summary tables, and one combined Excel workbook.
On Windows, this folder opens automatically when the script finishes.

---

## What each part of the script does

The script is organized into numbered sections, in this order:

**1) Packages** - checks for and installs the R packages the script
needs, then loads them.

**2) User settings** - where `input_dir` lives (see above), and two
tables that control the whole analysis:
- `assignment_map`: which journal is which, in what order, and what
  filename pattern identifies each one's CSV file.
- `wil_definitions`: the formulas for the four combined "Work-Integrated
  Learning" scores (Thinking, Social Leadership, Work & Lifestyle,
  Experiential), each built by averaging a couple of the more detailed
  LIWC metrics together.

**3) Helper functions** - small reusable pieces the rest of the script
calls repeatedly: matching a filename pattern to an actual file,
computing a weighted average, converting a raw metric name like
`cogproc` into a readable label like "Cognition," and so on. You
generally won't need to touch this section, but a couple of the
functions here are the ones you'd edit for the label-changing scenarios
below, so it's worth knowing they're here.

**4) Find and read files** - looks in `input_dir`, matches each CSV
file to the right row in `assignment_map` using the `file_pattern`
column, and reads them all in.

**5) Anonymize and accumulate segments** - some LIWC exports split one
student's submission into multiple rows (segments) if it was a longer
document. This section combines those back into one row per student
per assignment, and replaces real filenames with anonymous labels like
"Student 1," "Student 2," and so on, before anything gets saved to a
file.

**6) Summary tables and tests** - computes averages, statistical tests
comparing assignments, and the trend-over-time models, then writes all
of these out as CSV files and one combined Excel workbook.

**7) Plot theme** - one shared visual style (fonts, angled axis
labels, legend position) applied to every graph, plus the function that
saves each finished graph as a `.png` file.

**8) Graph generation** - builds each individual graph. This is the
section you'll come back to most often; see below.

**9) Exam question mapping** - commented out by default. This is a
scaffold for comparing exam question answers against the reflection
journals, for once that data exists. See "Using the exam question
comparison section" below.

---

## How the graphs are created

Every graph follows the same basic recipe:

1. The accumulated student data (one row per student per assignment)
   gets summarized into averages per assignment, per metric.
2. That summary gets handed to `ggplot()`, which is the R graphing
   library this script uses. Each graph is built by layering pieces
   together with `+`: the data and axes first, then the visual style
   (bars, lines, tiles for a heatmap), then colors, then titles and
   labels.
3. The finished graph is handed to `save_plot()`, which saves it as a
   `.png` file into the output folder at a set width, height, and
   resolution.

The graphs produced, in order:

- **`01_dataset_coverage.png`** - how many student texts were found for
  each assignment.
- **`02_normalized_z_score_heatmap.png`** - the normalized heatmap. Each
  cell shows how high or low that assignment scored on that metric,
  relative to the average across all assignments (a z-score), so
  metrics on very different natural scales can be compared side by
  side.
- **`03_grouped_bar_base_liwc_metrics.png`** - bar graph of the core
  LIWC metrics, grouped by assignment.
- **`04_wil_bar_graph.png`** - the same idea, for the four combined
  Work-Integrated Learning scores.
- **`05_violin_[metric name].png`** - one violin plot per core metric,
  showing the full spread of scores (not just the average) across
  students for each assignment.
- **`06_corrected_chronological_trends.png`** - a small line graph per
  metric, showing how it moves across the term in the corrected
  assignment order.
- **`07_metric_correlation_heatmap.png`** - how strongly each pair of
  metrics moves together across all the data.

---

## Common scenarios

### A new LIWC file needs to be added (for example, a term test)

1. Put the new CSV file in the same folder as `input_dir` points to.
2. Open the script and find `assignment_map` (in section 2). It's a
   table with one row per assignment. Either fill in the existing
   "Term Test" row's details, or add a new row in the same format:
   ```r
   7, "New Assignment Name", "Short Name", "Due date", "part_of_filename_here", "notes",
   ```
3. The `file_pattern` column (5th one) is what the script searches
   filenames for - it doesn't need to be the whole filename, just a
   distinctive part of it. For example, `"Term|Test|Exam|Question"`
   matches any filename containing any of those words.
4. Re-run the whole script. The new assignment will automatically flow
   through every table and every graph, no other changes needed.

### A file got renamed and the script says it's missing

The script matches files by searching for the text in the
`file_pattern` column somewhere in the filename - it does not require
an exact filename match. If a file was renamed enough that it no longer
contains that text, the script will report it under "Missing / skipped
files" when it runs. Either rename the file back so it contains the
expected text, or update the matching pattern in `assignment_map` to
match the new filename instead.

### The files moved to a different folder, or you're processing a
different course/term's data

Update `input_dir` (see "The one filepath you need to set" above) to
point at the new folder, then re-run the whole script. Everything else
adjusts automatically based on whatever files it finds there.

### You want to change what a graph's title, subtitle, or axis labels say

Every graph in section 8 has a block that looks like this:

```r
labs(
  title = "MGHC23 Fall 2025: Normalized LIWC Profile by Assignment",
  subtitle = "Z-scores show whether each assignment is high or low...",
  x = "Assignments in chronological order",
  y = "LIWC metric",
  fill = "Z-score"
)
```

Find the graph you want to change (they're labeled with comments like
`# 8.2 Professor-liked normalized z-score heatmap`), edit the text
inside the quotation marks, and re-run the script.

### You want to change how a specific metric's name is displayed (for
example, showing "Cognitive Processing" instead of "Cognition")

Metric names shown on every graph come from one place: the
`metric_label()` function in section 3. It's a simple lookup list:

```r
metric_label <- function(x) {
  dplyr::recode(
    x,
    analytic = "Analytic",
    tone = "Tone",
    cognition = "Cognition",
    ...
  )
}
```

Change the text on the right-hand side of the entry you want (for
example, change `cognition = "Cognition"` to
`cognition = "Cognitive Processing"`), and every graph that uses that
metric will update automatically. You do not need to edit each graph
individually.

### You want to change how an assignment's name is displayed on graphs

That comes from the `short_name` column in `assignment_map` (section
2). For example, changing `"IAM Pie Chart"` to something else there
updates every graph's x-axis and legend labels for that assignment,
without touching anything else.

### You want to change the colors in a heatmap

The heatmaps use a three-color gradient set with `scale_fill_gradient2`,
for example:

```r
scale_fill_gradient2(low = "#2c7bb6", mid = "white", high = "#d7191c", midpoint = 0, ...)
```

`low` and `high` are hex color codes for the two ends of the scale
(currently blue and red), `mid` is the color at the midpoint. Replace
any of these with a different hex color code (a 6-character code
starting with `#` - a quick web search for "hex color picker" will get
you one) and re-run.

### You want to change the size or resolution of the saved image files

Each graph is saved with a line like:

```r
save_plot(p_z_heatmap, "02_normalized_z_score_heatmap.png", width = 13, height = 8)
```

`width` and `height` are in inches, and there's an optional `dpi`
(resolution) argument too, which defaults to 300. Increase these if a
graph looks cramped or text is overlapping; decrease them if the file
size needs to be smaller.

### Using the exam question comparison section (section 9)

This section is commented out (every line starts with `#`), which
means R ignores it entirely as written. It's a starting point for
comparing exam question answers against the reflection journal scores,
built for once that comparison becomes possible. To use it:

1. Read through the notes at the top of the section first - two of the
   mapped questions have an unresolved detail worth double-checking
   before trusting the output (noted directly in the comments there).
2. Remove the `#` from the start of each line you want to activate.
3. You will need a `midterm_scores.csv` file with one row per student
   and one column per question (Q1 through Q7) - the section expects
   this and will tell you if it's missing.
4. Read the note about `anon_student_id` before joining anything - the
   student ID numbers generated by this script are not guaranteed to
   line up with a separately-created scores file unless both come from
   the same script run, so a translation step may be needed first.

---

## Troubleshooting

**A package fails to install**
Occasionally one package needs a system-level tool that isn't
installed yet (this is more common on Mac than Windows). The error
message R gives usually names the specific package - a web search for
"[package name] R install error" plus whatever the error says is
usually enough to resolve it.

**"No CSV files were found"**
`input_dir` is pointing at a folder that doesn't contain any CSV files,
or doesn't exist. Double check the path as described above.

**A specific assignment shows up as "Missing / skipped"**
The file for that assignment either isn't in the folder, or its
filename doesn't contain the text in that row's `file_pattern` column.
See "A file got renamed" above.

**"object not found" or similar errors partway through**
This usually means the script was run partially, or a section was
skipped. Re-run the entire script from the top with Source, rather than
running individual chunks.

**A graph looks empty, or a metric is missing from it**
Check the "Missing / skipped files" message from when the script ran -
if the underlying assignment's file wasn't found, any graph that
depends on it will be missing that assignment's data, not the whole
graph.
