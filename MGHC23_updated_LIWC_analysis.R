# MGHC23_LIWC_analysis_same_folder_FIXED_v2.R
# Purpose: Corrected MGHC23 LIWC analysis from LIWC CSV files placed in the SAME folder as this script.
# Outputs: z-score heatmap, bar graphs, violin plots, trend plots, correlation heatmap, and summary tables.
# Fix in this version: metadata numeric columns such as assignment_order are excluded from LIWC metric aggregation.

# =========================
# 1) PACKAGES
# =========================
packages <- c(
  "readr", "dplyr", "tidyr", "janitor", "ggplot2", "stringr",
  "purrr", "forcats", "openxlsx", "scales", "tibble", "rlang", "broom"
)

missing_packages <- packages[!packages %in% rownames(installed.packages())]
if (length(missing_packages) > 0) install.packages(missing_packages)
invisible(lapply(packages, library, character.only = TRUE))

# =========================
# 2) USER SETTINGS
# =========================
# OPTION A: leave blank and run setwd("...") before source().
# OPTION B: paste the exact folder path here.
input_dir <- "C:/Users/anama/Downloads/MGT-C23_LIWCs_Rscript"
if (input_dir == "") input_dir <- getwd()

output_dir <- file.path(input_dir, "MGHC23_LIWC_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

message("Input folder: ", normalizePath(input_dir, winslash = "/", mustWork = FALSE))
message("Output folder: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))

# Correct chronological order from professor email.
assignment_map <- tibble::tribble(
  ~assignment_order, ~assignment_name, ~short_name, ~due_date, ~file_pattern, ~exam_mapping_note,
  1, "Cultural Circle Journal", "Cultural Circle", "Sep 15", "Cultural[ _]Circle", "Q1 primary source: Stereotyping",
  2, "Reflect on IAM & Pie Chart Exercise Journal", "IAM Pie Chart", "Sep 29", "IAM[ _]Pie", "Q3 clean match: Internalized/Socialized Stereotypes",
  3, "Sexual Privilege Journal", "Sexual Privilege", "Sep 29", "Sexual[ _]Privilege", "Q2 primary source: Prejudice",
  4, "Privilege Exercises Journal", "Privilege Exercises", "Oct 20", "Privilege[ _]Exercises", "Q4 exploratory direct source; full sequence is primary",
  5, "University Case Synchronous Session Journal", "University Case", "Nov 16", "University[ _]Case", "Q6 primary source: UofT identity/discrimination",
  6, "Term Test", "Term Test", "Nov 17", "Term|Test|Exam|Question", "Term Test not included unless matching LIWC file is present"
)

# Main LIWC metrics for TASME-style outputs.
base_metrics <- c(
  "analytic", "tone", "perception", "insight", "cause",
  "allure", "curiosity", "prosocial"
)

# Professor-requested WIL dimensions: Thinking = mean(Analytic, Cognition).
# NOTE: confirmed against the actual LIWC-22 exports that "Cognition" and
# "cogproc" are BOTH present as distinct columns (not aliases for the same
# metric - they hold different values). An earlier version of this list
# included cogproc as a defensive fallback in case only the old column name
# was present, but since both columns exist in these files, that silently
# pulled cogproc into a 3-way average instead of the professor's specified
# 2-way mean(Analytic, Cognition). Fixed to use "cognition" only, which
# matches both the professor's email and kalen-draft.pdf's own definition
# ("Thinking, comprised of Analytic and Cognition").
wil_definitions <- list(
  thinking = c("analytic", "cognition"),
  social_leadership = c("clout", "social"),
  work_lifestyle = c("lifestyle", "work"),
  experiential = c("perception", "space", "tone")
)

# =========================
# 3) HELPER FUNCTIONS
# =========================
clean_file_label <- function(x) {
  x %>%
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") %>%
    stringr::str_replace_all("^_|_$", "")
}

metric_label <- function(x) {
  dplyr::recode(
    x,
    analytic = "Analytic",
    tone = "Tone",
    perception = "Perception",
    insight = "Insight",
    cause = "Cause",
    allure = "Allure",
    curiosity = "Curiosity",
    prosocial = "Prosocial",
    cognition = "Cognition",
    cogproc = "Cognition",
    clout = "Clout",
    social = "Social",
    lifestyle = "Lifestyle",
    work = "Work",
    space = "Space",
    thinking = "Thinking",
    social_leadership = "Social Leadership",
    work_lifestyle = "Work & Lifestyle",
    experiential = "Experiential",
    .default = stringr::str_to_title(x)
  )
}

weighted_mean_safe <- function(x, w) {
  ok <- !is.na(x) & !is.na(w) & w > 0
  if (sum(ok) == 0) return(NA_real_)
  weighted.mean(x[ok], w[ok])
}

row_mean_existing <- function(data, cols) {
  existing <- intersect(cols, names(data))
  if (length(existing) == 0) return(rep(NA_real_, nrow(data)))
  rowMeans(data[, existing, drop = FALSE], na.rm = TRUE)
}

z_score_safe <- function(x) {
  if (all(is.na(x)) || is.na(sd(x, na.rm = TRUE)) || sd(x, na.rm = TRUE) == 0) {
    return(rep(NA_real_, length(x)))
  }
  as.numeric(scale(x))
}

read_liwc_csv <- function(path) {
  readr::read_csv(path, show_col_types = FALSE, na = c("", ".", "NA", "NaN")) %>%
    janitor::clean_names()
}

find_assignment_file <- function(pattern) {
  all_csvs <- list.files(input_dir, pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)
  all_csvs <- all_csvs[!grepl("^~\\$", basename(all_csvs))]
  hits <- all_csvs[grepl(pattern, basename(all_csvs), ignore.case = TRUE, perl = TRUE)]
  if (length(hits) == 0) return(NA_character_)
  hits[order(file.info(hits)$mtime, decreasing = TRUE)][1]
}

# =========================
# 4) FIND AND READ FILES
# =========================
message("CSV files seen by R in this folder:")
print(list.files(input_dir, pattern = "\\.csv$", ignore.case = TRUE))

file_lookup <- assignment_map %>%
  mutate(path = purrr::map_chr(file_pattern, find_assignment_file))

# Export basename only, not the full local machine path (e.g. C:/Users/anama/...),
# since this file is meant to go into a shared handoff.
file_lookup_export <- file_lookup %>% mutate(path = basename(path))
readr::write_csv(file_lookup_export, file.path(output_dir, "00_corrected_order_map_and_file_lookup.csv"))

missing_files <- file_lookup %>% filter(is.na(path))
if (nrow(missing_files) > 0) {
  message("Missing / skipped files:")
  print(missing_files %>% select(assignment_order, assignment_name, file_pattern))
}

raw_data <- purrr::pmap_dfr(
  file_lookup %>% filter(!is.na(path)),
  function(assignment_order, assignment_name, short_name, due_date, file_pattern, exam_mapping_note, path) {
    message("Reading: ", basename(path), "  ->  ", assignment_name)
    df <- read_liwc_csv(path)
    df %>%
      mutate(
        course_code = "MGHC23",
        term = "Fall 2025",
        assignment_order = assignment_order,
        assignment_name = assignment_name,
        short_name = short_name,
        due_date = due_date,
        exam_mapping_note = exam_mapping_note,
        source_file = basename(path)
      )
  }
)

if (nrow(raw_data) == 0) {
  stop("No LIWC files were found. Run setwd() to the folder containing the CSV files, or set input_dir manually at the top of this script.")
}

if (!"filename" %in% names(raw_data)) stop("Expected a Filename column in the LIWC files.")
if (!"wc" %in% names(raw_data)) stop("Expected a WC column in the LIWC files.")
if (!"segment" %in% names(raw_data)) raw_data$segment <- 1

# =========================
# 5) ANONYMIZE AND ACCUMULATE SEGMENTS
# =========================
raw_data <- raw_data %>%
  mutate(
    original_student_id = stringr::str_extract(filename, "^[^_\\.]+"),
    original_student_id = ifelse(is.na(original_student_id), filename, original_student_id)
  )

metadata_cols <- c(
  "course_code", "term", "assignment_order", "assignment_name", "short_name", "due_date",
  "exam_mapping_note", "filename", "original_student_id", "source_file"
)

numeric_cols <- names(raw_data)[sapply(raw_data, is.numeric)]

# Important fix:
# Some metadata columns, such as assignment_order, are numeric but are NOT LIWC metrics.
# They must be excluded before weighted LIWC aggregation.
liwc_numeric_cols <- setdiff(numeric_cols, c("segment", metadata_cols))
metrics_to_weight <- setdiff(liwc_numeric_cols, "wc")

message("Numeric LIWC columns used for analysis:")
print(liwc_numeric_cols)

accumulated <- raw_data %>%
  group_by(across(all_of(metadata_cols))) %>%
  summarize(
    segment_count = n(),
    wc = sum(wc, na.rm = TRUE),
    across(all_of(metrics_to_weight), ~ weighted_mean_safe(.x, wc), .names = "{.col}"),
    .groups = "drop"
  ) %>%
  group_by(course_code, term) %>%
  mutate(anon_student_id = paste0("Student ", dense_rank(original_student_id))) %>%
  ungroup() %>%
  # Drop identifying columns now that anon_student_id exists. filename and
  # source_file contain full real student names and Quercus submission IDs
  # (e.g. "nguyennina_632358_39189276_...") - these must not appear in any
  # written output (CSV/xlsx), which is a real handoff/publication concern.
  select(-original_student_id, -filename, -source_file)

# Add professor-requested WIL dimensions.
accumulated <- accumulated %>%
  mutate(
    thinking = row_mean_existing(cur_data_all(), wil_definitions$thinking),
    social_leadership = row_mean_existing(cur_data_all(), wil_definitions$social_leadership),
    work_lifestyle = row_mean_existing(cur_data_all(), wil_definitions$work_lifestyle),
    experiential = row_mean_existing(cur_data_all(), wil_definitions$experiential)
  )

base_metrics_available <- intersect(base_metrics, names(accumulated))
wil_metrics <- c("thinking", "social_leadership", "work_lifestyle", "experiential")
wil_metrics_available <- intersect(wil_metrics, names(accumulated))
all_plot_metrics <- c(base_metrics_available, wil_metrics_available)

# =========================
# 6) SUMMARY TABLES AND TESTS
# =========================
long_metrics <- accumulated %>%
  select(course_code, term, assignment_order, assignment_name, short_name, due_date,
         exam_mapping_note, anon_student_id, segment_count, wc,
         all_of(all_plot_metrics)) %>%
  pivot_longer(cols = all_of(all_plot_metrics), names_to = "metric", values_to = "value") %>%
  filter(!is.na(value)) %>%
  mutate(
    metric_label = metric_label(metric),
    short_name = forcats::fct_reorder(short_name, assignment_order)
  )

descriptives <- long_metrics %>%
  group_by(assignment_order, assignment_name, short_name, due_date, metric, metric_label) %>%
  summarize(
    n_texts = n(),
    n_students = n_distinct(anon_student_id),
    mean = mean(value, na.rm = TRUE),
    median = median(value, na.rm = TRUE),
    sd = sd(value, na.rm = TRUE),
    iqr = IQR(value, na.rm = TRUE),
    min = min(value, na.rm = TRUE),
    max = max(value, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(metric, assignment_order)

kw_tests <- long_metrics %>%
  group_by(metric, metric_label) %>%
  group_modify(function(.x, .y) {
    if (nrow(.x) < 6 || n_distinct(.x$assignment_name) < 2 || length(unique(.x$value)) < 2) {
      return(tibble(kw_statistic = NA_real_, kw_p = NA_real_))
    }
    test <- suppressWarnings(kruskal.test(value ~ assignment_name, data = .x))
    tibble(kw_statistic = unname(test$statistic), kw_p = test$p.value)
  }) %>%
  ungroup() %>%
  mutate(kw_p_fdr = p.adjust(kw_p, method = "BH")) %>%
  arrange(kw_p_fdr)

trend_models <- long_metrics %>%
  group_by(metric, metric_label) %>%
  group_modify(function(.x, .y) {
    if (nrow(.x) < 6 || n_distinct(.x$assignment_order) < 2 || length(unique(.x$value)) < 2) {
      return(tibble(term = "assignment_order", estimate = NA_real_, std_error = NA_real_, statistic = NA_real_, p_value = NA_real_))
    }
    fit <- lm(value ~ assignment_order, data = .x)
    broom::tidy(fit) %>%
      filter(term == "assignment_order") %>%
      transmute(
        term = term,
        estimate = estimate,
        std_error = std.error,
        statistic = statistic,
        p_value = p.value
      )
  }) %>%
  ungroup() %>%
  mutate(p_fdr = p.adjust(p_value, method = "BH")) %>%
  arrange(p_fdr)

# Pairwise tests for base metrics only, so output is not too large.
pairwise_tests <- purrr::map_dfr(base_metrics_available, function(m) {
  df <- accumulated %>%
    select(short_name, assignment_name, value = all_of(m)) %>%
    drop_na(value)
  if (nrow(df) < 6 || n_distinct(df$assignment_name) < 2) {
    return(tibble(metric = m, group1 = NA_character_, group2 = NA_character_, p_fdr = NA_real_))
  }
  pw <- pairwise.wilcox.test(df$value, df$assignment_name, p.adjust.method = "BH", exact = FALSE)
  as.data.frame(as.table(pw$p.value)) %>%
    filter(!is.na(Freq)) %>%
    transmute(metric = m, metric_label = metric_label(m), group1 = as.character(Var1), group2 = as.character(Var2), p_fdr = Freq)
})

# Correlation table for selected base metrics and WILs.
cor_data <- accumulated %>% select(all_of(all_plot_metrics))
cor_matrix <- cor(cor_data, use = "pairwise.complete.obs", method = "pearson")
cor_table <- as.data.frame(cor_matrix) %>% tibble::rownames_to_column("metric")

# Normalized heatmap data: z-score within each metric across assignment means.
heatmap_data <- descriptives %>%
  group_by(metric, metric_label) %>%
  mutate(z_mean = z_score_safe(mean)) %>%
  ungroup()

readr::write_csv(accumulated, file.path(output_dir, "01_anonymized_accumulated_student_assignment_data.csv"))
readr::write_csv(descriptives, file.path(output_dir, "02_descriptives_by_assignment_metric.csv"))
readr::write_csv(kw_tests, file.path(output_dir, "03_kruskal_tests_by_metric.csv"))
readr::write_csv(trend_models, file.path(output_dir, "04_corrected_chronological_trend_models.csv"))
readr::write_csv(pairwise_tests, file.path(output_dir, "05_pairwise_assignment_tests_base_metrics.csv"))
readr::write_csv(heatmap_data, file.path(output_dir, "06_z_score_heatmap_data.csv"))
readr::write_csv(cor_table, file.path(output_dir, "07_correlation_matrix.csv"))

openxlsx::write.xlsx(
  list(
    file_lookup = file_lookup_export,
    accumulated_anonymized = accumulated,
    descriptives = descriptives,
    kruskal_tests = kw_tests,
    trend_models_corrected_order = trend_models,
    pairwise_tests = pairwise_tests,
    z_score_heatmap_data = heatmap_data,
    correlation_matrix = cor_table
  ),
  file = file.path(output_dir, "MGHC23_LIWC_summary_tables.xlsx"),
  overwrite = TRUE
)

# =========================
# 7) PLOT THEME
# =========================
theme_mghc23 <- function(base_size = 13) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = base_size + 4),
      plot.subtitle = element_text(size = base_size),
      axis.text.x = element_text(angle = 35, hjust = 1),
      panel.grid.minor = element_blank(),
      legend.position = "bottom"
    )
}

save_plot <- function(plot, filename, width = 12, height = 7, dpi = 300) {
  ggsave(file.path(output_dir, filename), plot = plot, width = width, height = height, dpi = dpi)
}

# =========================
# 8) GRAPH GENERATION
# =========================
# 8.1 Dataset coverage
coverage <- accumulated %>%
  count(assignment_order, short_name, assignment_name, name = "n_texts") %>%
  arrange(assignment_order)

p_coverage <- ggplot(coverage, aes(x = forcats::fct_reorder(short_name, assignment_order), y = n_texts)) +
  geom_col() +
  theme_mghc23() +
  labs(
    title = "MGHC23 Fall 2025 LIWC Dataset Coverage",
    subtitle = "Term Test is skipped unless its LIWC file is added",
    x = "Assignments in chronological order",
    y = "Number of accumulated student texts"
  )
save_plot(p_coverage, "01_dataset_coverage.png", width = 10, height = 6)

# 8.2 Professor-liked normalized z-score heatmap
p_z_heatmap <- ggplot(
  heatmap_data,
  aes(x = forcats::fct_reorder(short_name, assignment_order), y = metric_label, fill = z_mean)
) +
  geom_tile(color = "white", linewidth = 0.6) +
  geom_text(aes(label = sprintf("%.2f", z_mean)), size = 3.2, na.rm = TRUE) +
  scale_fill_gradient2(low = "#2c7bb6", mid = "white", high = "#d7191c", midpoint = 0, na.value = "grey90") +
  theme_mghc23() +
  labs(
    title = "MGHC23 Fall 2025: Normalized LIWC Profile by Assignment",
    subtitle = "Z-scores show whether each assignment is high or low relative to the course mean for that metric",
    x = "Assignments in chronological order",
    y = "LIWC metric",
    fill = "Z-score"
  )
save_plot(p_z_heatmap, "02_normalized_z_score_heatmap.png", width = 13, height = 8)

# 8.3 Grouped bar graph for base LIWC metrics
bar_base <- descriptives %>% filter(metric %in% base_metrics_available)

p_base_bar <- ggplot(
  bar_base,
  aes(x = metric_label, y = mean, fill = forcats::fct_reorder(short_name, assignment_order))
) +
  geom_col(position = position_dodge(width = 0.8), width = 0.75) +
  theme_mghc23() +
  labs(
    title = "MGHC23 Fall 2025: Mean LIWC Scores by Assignment",
    subtitle = "Corrected chronology; segmented reflections accumulated first",
    x = "LIWC metric",
    y = "Mean LIWC score",
    fill = "Assignment"
  )
save_plot(p_base_bar, "03_grouped_bar_base_liwc_metrics.png", width = 14, height = 7)

# 8.4 Metric dimension bar graph
bar_comp <- descriptives %>% filter(metric %in% wil_metrics_available)

if (nrow(bar_comp) > 0) {
  p_comp_bar <- ggplot(
    bar_comp,
    aes(x = metric_label, y = mean, fill = forcats::fct_reorder(short_name, assignment_order))
  ) +
    geom_col(position = position_dodge(width = 0.8), width = 0.75) +
    theme_mghc23() +
    labs(
      title = "MGHC23 Fall 2025: WIL LIWC Dimensions",
      subtitle = "Thinking, Social Leadership, Work & Lifestyle, and Experiential WILs",
      x = "WIL dimension",
      y = "Mean WIL score",
      fill = "Assignment"
    )
  save_plot(p_comp_bar, "04_wil_bar_graph.png", width = 12, height = 7)
}

# 8.5 One violin plot per base metric
for (m in base_metrics_available) {
  dat <- accumulated %>%
    select(assignment_order, short_name, value = all_of(m)) %>%
    drop_na(value) %>%
    mutate(short_name = forcats::fct_reorder(short_name, assignment_order))
  
  if (nrow(dat) >= 6 && n_distinct(dat$short_name) >= 2) {
    p <- ggplot(dat, aes(x = short_name, y = value)) +
      geom_violin(trim = FALSE, alpha = 0.55) +
      geom_boxplot(width = 0.12, outlier.shape = NA, alpha = 0.75) +
      geom_point(position = position_jitter(width = 0.08, height = 0), alpha = 0.35, size = 1.4) +
      theme_mghc23() +
      labs(
        title = paste0("MGHC23 Fall 2025: ", metric_label(m), " by Assignment"),
        subtitle = "One row per student-assignment after segment accumulation",
        x = "Assignments in chronological order",
        y = paste("LIWC", metric_label(m))
      )
    save_plot(p, paste0("05_violin_", clean_file_label(m), ".png"), width = 12, height = 7)
  }
}

# 8.6 Corrected chronological trend plot
trend_plot_data <- descriptives %>%
  filter(metric %in% all_plot_metrics) %>%
  mutate(metric_label = factor(metric_label, levels = unique(metric_label)))

p_trends <- ggplot(trend_plot_data, aes(x = assignment_order, y = mean, group = metric_label)) +
  geom_line() +
  geom_point(size = 2) +
  facet_wrap(~ metric_label, scales = "free_y") +
  scale_x_continuous(breaks = coverage$assignment_order, labels = coverage$short_name) +
  theme_mghc23(base_size = 11) +
  labs(
    title = "MGHC23 Fall 2025: Corrected Chronological Trends",
    subtitle = "IAM Pie Chart is correctly placed between Cultural Circle and Sexual Privilege",
    x = "Assignments in chronological order",
    y = "Mean score"
  )
save_plot(p_trends, "06_corrected_chronological_trends.png", width = 14, height = 9)

# 8.7 Correlation heatmap
cor_long <- as.data.frame(cor_matrix) %>%
  tibble::rownames_to_column("metric_x") %>%
  pivot_longer(cols = -metric_x, names_to = "metric_y", values_to = "r") %>%
  mutate(
    metric_x_label = metric_label(metric_x),
    metric_y_label = metric_label(metric_y)
  )

p_cor <- ggplot(cor_long, aes(x = metric_x_label, y = metric_y_label, fill = r)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.2f", r)), size = 3, na.rm = TRUE) +
  scale_fill_gradient2(low = "#2c7bb6", mid = "white", high = "#d7191c", midpoint = 0, limits = c(-1, 1), na.value = "grey90") +
  theme_mghc23(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(
    title = "MGHC23 Fall 2025: Correlations Between LIWC Metrics",
    subtitle = "Pearson correlations across accumulated student-assignment rows",
    x = "Metric",
    y = "Metric",
    fill = "r"
  )
save_plot(p_cor, "07_metric_correlation_heatmap.png", width = 10, height = 9)

message("\nAnalysis complete.")
message("Outputs saved to: ", normalizePath(output_dir, winslash = "/"))
message("Main workbook: ", normalizePath(file.path(output_dir, "MGHC23_LIWC_summary_tables.xlsx"), winslash = "/"))

# Open output folder on Windows.
if (.Platform$OS.type == "windows") {
  shell.exec(normalizePath(output_dir, winslash = "\\", mustWork = FALSE))
}

# =========================
# 9) EXAM QUESTION <-> REFLECTION MAPPING (FOR IRAA - MIDTERM COMPARISON)
# =========================
# Everything below is commented out. It is a scaffold, not a finished
# analysis - three of the seven questions reference sources that are not
# yet in this folder (see the 'available_now' column). Uncomment this
# section and supply a midterm_scores.csv once that data exists; the rest
# is written to run as-is against the journals we already have.
#
# exam_question_map <- tibble::tribble(
#   ~question, ~question_topic, ~primary_sources, ~exploratory_sources, ~available_now, ~notes,
#   "Q1", "Stereotyping",
#     "Cultural Circle", NA_character_, TRUE,
#     "Exam wording is disjunctive (Cultural Circles OR Orange Shirt Day/Campus Farm Day activities). Also draws on Feedback on Indigenous Learning Events homework (due Nov 3) - CONFIRMED NOT in this dataset. Tag separately as an additional Q1 source if it's added later, do not merge into the Cultural Circle numbers.",
#   "Q2", "Prejudice",
#     "Sexual Privilege", NA_character_, TRUE,
#     "Exam also requires SDO/sexism Qualtrics survey scores - structured numeric data, CONFIRMED NOT in this dataset. If added, keep as its own columns and do NOT fold into the LIWC metric averaging below.",
#   "Q3", "Internalized/Socialized Stereotypes",
#     "IAM Pie Chart", NA_character_, TRUE,
#     "Clean match, no change.",
#   "Q4", "Valuing Diversity",
#     "IAM Pie Chart|Sexual Privilege|Privilege Exercises", "Privilege Exercises (direct pairing, exploratory only)", TRUE,
#     "Primary model is the full sequence across the 3 listed sources, averaged per student. CONFIRM with professor whether Cultural Circle should be a 4th source - her note says 'these four exercises' but only 3 are listed here.",
#   "Q5", "Managing Diversity (Canada & South Africa)",
#     "Cultural Circle", NA_character_, TRUE,
#     "Same journal as Q1 - do NOT pool with Q1, Q6, or Q7. Does NOT map to University Case Journal despite topical overlap with Q6.",
#   "Q6", "UofT identity data / discrimination",
#     "University Case", NA_character_, TRUE,
#     "Clean match.",
#   "Q7", "Harassment/discrimination recommendations",
#     "University Case|Promotion Role Play|Hoo Hoo Club", NA_character_, FALSE,
#     "Promotion Role Play (due Nov 3) and Hoo Hoo Club Case Session Plan (due Nov 9) CONFIRMED NOT in this dataset as of this script version. University Case alone will under-explain Q7 per the exam wording - flag this gap explicitly in the handover report until the other two files are added."
# )
#
# ---- Helper: per-student composite score across a question's source journal(s) ----
# For questions with more than one primary source (Q4, eventually Q7), this
# averages the WIL dimensions across all mapped journals for each student,
# giving one row per student per question to compare against their midterm
# score for that question. Swap 'metrics' for specific base LIWC metrics
# instead of WIL dimensions if that's a better fit for a given question.
#
# get_question_composite <- function(sources_pattern, metrics = wil_metrics_available) {
#   accumulated %>%
#     filter(short_name %in% stringr::str_split(sources_pattern, "\\|")[[1]]) %>%
#     group_by(anon_student_id) %>%
#     summarize(across(all_of(metrics), ~ mean(.x, na.rm = TRUE)), n_sources = dplyr::n(), .groups = "drop")
# }
#
# question_composites <- exam_question_map %>%
#   filter(available_now) %>%
#   mutate(composite = purrr::map(primary_sources, get_question_composite)) %>%
#   select(question, question_topic, composite) %>%
#   tidyr::unnest(composite)
#
# ---- Join with midterm scores once available ----
# Expected shape: one row per student, one column per question (Q1..Q7),
# with anon_student_id as the join key. IMPORTANT: anon_student_id here is
# regenerated fresh each run from dense_rank(original_student_id) - if the
# midterm scores file uses a DIFFERENT identifier (e.g. Quercus ID), build
# a lookup table to translate between the two before joining, since
# dense_rank order is not guaranteed stable if the set of input files
# changes between runs.
#
# midterm_scores <- readr::read_csv(file.path(input_dir, "midterm_scores.csv"))
#   # expected columns: anon_student_id, Q1, Q2, Q3, Q4, Q5, Q6, Q7
#
# question_vs_midterm <- question_composites %>%
#   left_join(
#     midterm_scores %>%
#       pivot_longer(starts_with("Q"), names_to = "question", values_to = "midterm_score"),
#     by = c("anon_student_id", "question")
#   )
#
# ---- Correlation between journal composite and midterm score, per question ----
# question_correlations <- question_vs_midterm %>%
#   group_by(question, question_topic) %>%
#   group_modify(function(.x, .y) {
#     numeric_cols <- setdiff(names(.x)[sapply(.x, is.numeric)], "midterm_score")
#     .x_complete <- .x %>% select(all_of(numeric_cols), midterm_score) %>% tidyr::drop_na()
#     if (nrow(.x_complete) < 6) return(tibble(metric = NA_character_, r = NA_real_, p = NA_real_))
#     purrr::map_dfr(numeric_cols, function(m) {
#       test <- suppressWarnings(cor.test(.x_complete[[m]], .x_complete$midterm_score))
#       tibble(metric = m, r = unname(test$estimate), p = test$p.value)
#     })
#   }) %>%
#   ungroup()
#
# readr::write_csv(question_correlations, file.path(output_dir, "08_exam_question_vs_journal_correlations.csv"))