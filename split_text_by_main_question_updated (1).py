from pathlib import Path
import re
import json
import csv


"""
Split extracted student .txt files by MAIN question number only.

This script is designed for term-test / final-exam responses where students may write:

    Question 1 ...
    Q1 ...
    1. ...
    1) ...
    6a. ...
    6(a) ...
    a) ...
    (b) ...

Important:
    - The output is grouped only as Q1, Q2, Q3, etc.
    - Subparts like a), b), c), 6a, 6b, 7(c) stay inside the main question.
    - Numbered lists inside an answer are not treated as new questions unless they are
      the expected next main question number.
"""


PAGE_MARKER_PATTERN = re.compile(
    r"^\s*---\s*Page\s+\d+\s*---\s*$",
    re.IGNORECASE
)

# Main question formats:
#   Question 1
#   Question 1:
#   Q1
#   Q1.
#   1.
#   1)
#   1:
#   1 -
#   6a.
#   6(a)
#
# Subpart letters attached to the question number are detected but ignored for grouping.
QUESTION_START_PATTERN = re.compile(
    r"""
    ^\s*
    (?P<prefix>question|q)?
    \s*
    (?P<num>\d{1,2})
    \s*
    (?P<subpart>
        \(?[a-zA-Z]\)?
    )?
    \s*
    (?P<punct>[\.\):\-])?
    \s*
    """,
    re.IGNORECASE | re.VERBOSE
)


def normalize_text(text: str) -> str:
    """Clean common invisible PDF extraction artifacts."""
    replacements = {
        "\ufeff": "",
        "\u200b": "",
        "\u200c": "",
        "\u200d": "",
        "\u2060": "",
        "\u00a0": " ",
        "●\t": "● ",
    }

    for old, new in replacements.items():
        text = text.replace(old, new)

    # Normalize line endings.
    text = text.replace("\r\n", "\n").replace("\r", "\n")

    return text


def get_question_candidate(line: str):
    """
    Returns (question_number, answer_start_index) if the line appears to begin
    with a question marker. Otherwise returns (None, None).

    This does not decide whether the candidate is a real split.
    """
    line_clean = line.strip()

    if not line_clean:
        return None, None

    match = QUESTION_START_PATTERN.match(line_clean)

    if not match:
        return None, None

    prefix = match.group("prefix")
    num = int(match.group("num"))
    punct = match.group("punct")

    # If the marker is "Question 1" or "Q1", accept even without punctuation.
    has_word_prefix = prefix is not None

    # If it is just "1" without punctuation, do not treat it as a question.
    if not has_word_prefix and punct is None:
        return None, None

    # Need answer_start relative to the original line, not stripped line.
    leading_spaces = len(line) - len(line.lstrip())
    answer_start = leading_spaces + match.end()

    return num, answer_start


def split_text_by_main_question(
    text: str,
    first_question: int = 1,
    last_question: int | None = None,
    allow_skipped_questions: bool = False,
) -> dict[str, str]:
    """
    Split text into Q1, Q2, Q3, etc.

    Parameters:
        first_question:
            Usually 1.

        last_question:
            Optional. If set to 7, the script will ignore candidate question numbers
            above 7.

        allow_skipped_questions:
            False is safer.
            If False, after Q1 the script only accepts Q2, then Q3, etc.
            This prevents internal numbered lists from being misread.

            If True, after Q1 the script accepts Q2 or higher.
            This can help if some students skip a question, but it increases risk
            of false splits from numbered lists.
    """
    text = normalize_text(text)
    lines = text.splitlines()

    questions = {}
    current_q = None
    expected_next_q = first_question
    buffer = []

    for line in lines:
        if PAGE_MARKER_PATTERN.match(line):
            continue

        candidate_q, answer_start = get_question_candidate(line)

        is_new_question = False

        if candidate_q is not None:
            if last_question is not None and candidate_q > last_question:
                is_new_question = False

            elif current_q is None:
                # Start only at the configured first question.
                is_new_question = candidate_q == first_question

            elif allow_skipped_questions:
                # More flexible but less safe.
                is_new_question = candidate_q > current_q

            else:
                # Safer mode: only accept the exact next question.
                is_new_question = candidate_q == expected_next_q

        if is_new_question:
            if current_q is not None:
                questions[f"Q{current_q}"] = "\n".join(buffer).strip()

            current_q = candidate_q
            expected_next_q = current_q + 1

            remaining = line[answer_start:].strip()
            buffer = [remaining] if remaining else []

        else:
            if current_q is not None:
                buffer.append(line)

    if current_q is not None:
        questions[f"Q{current_q}"] = "\n".join(buffer).strip()

    return questions


def natural_question_sort(label: str) -> int:
    """Sort Q1, Q2, Q10 correctly."""
    match = re.search(r"\d+", label)
    return int(match.group()) if match else 9999


def convert_txt_folder(
    input_folder: str = "txt_output",
    output_folder: str = "split_by_main_question",
    first_question: int = 1,
    last_question: int | None = 7,
    allow_skipped_questions: bool = False,
) -> None:
    input_dir = Path(input_folder)
    output_dir = Path(output_folder)
    output_dir.mkdir(parents=True, exist_ok=True)

    txt_files = sorted(input_dir.glob("*.txt"))

    if not txt_files:
        print(f"No .txt files found in: {input_dir.resolve()}")
        return

    all_rows = []

    for txt_file in txt_files:
        text = txt_file.read_text(encoding="utf-8", errors="replace")

        questions = split_text_by_main_question(
            text=text,
            first_question=first_question,
            last_question=last_question,
            allow_skipped_questions=allow_skipped_questions,
        )

        # Sort questions naturally.
        questions = {
            key: questions[key]
            for key in sorted(questions.keys(), key=natural_question_sort)
        }

        json_path = output_dir / f"{txt_file.stem}_main_questions.json"
        json_path.write_text(
            json.dumps(questions, indent=2, ensure_ascii=False),
            encoding="utf-8"
        )

        for question_label, answer_text in questions.items():
            all_rows.append({
                "student_file": txt_file.name,
                "question": question_label,
                "answer": answer_text
            })

        print(f"Processed: {txt_file.name}")
        print(f"Questions found: {', '.join(questions.keys()) if questions else 'none'}")
        print(f"Saved: {json_path.name}\n")

    csv_path = output_dir / "all_students_main_questions.csv"

    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["student_file", "question", "answer"]
        )
        writer.writeheader()
        writer.writerows(all_rows)

    print(f"Combined CSV saved to: {csv_path.resolve()}")


if __name__ == "__main__":
    convert_txt_folder(
        input_folder="txt_output",
        output_folder="split_by_main_question",
        first_question=1,
        last_question=7,
        allow_skipped_questions=False,
    )
