# Quick Reference

*For full explanations, setup instructions, and troubleshooting, see
README.md. This page is just a reminder once you've already done it
once.*

## Every time you have a new batch of exams:

1. Put the PDF/DOCX files in a folder.
2. Open `convert_exam_files_to_txt.py` in Notepad, update this line to
   point at that folder, save:
   ```python
   INPUT_FOLDER = r"C:\your\folder\path\here"
   ```
3. In PowerShell, in the script's folder:
   ```
   python convert_exam_files_to_txt.py
   ```
4. Then:
   ```
   python split_text_by_main_question_updated.py
   ```
5. Open `split_by_main_question\all_students_main_questions.csv` in
   Excel - that's your result.

## If something goes wrong

Check README.md -> "Troubleshooting." If it's not covered there, keep a
note of the exact error message plus which step it happened on.
