# Loop over all found .tex source files and compile
for latex_file in ${source_files}; do
  # Get the filename without .tex (e.g., HamersKiraBP)
  filename=$(basename "${latex_file}" .tex)
  
  echo "========== Compiling ${filename} =========="
  
  # 1. First pass: Generate auxiliary files in the output folder
  xelatex -shell-escape -interaction=nonstopmode -output-directory="${output_dir}" "${latex_file}"
  
  # 2. Biber: Explicitly tell it where the input and output live
  # This fixes the "Undefined Citation" errors
  biber --input-directory "${output_dir}" --output-directory "${output_dir}" "${filename}"
  
  # 3. Final passes: Link the bibliography and Table of Contents
  xelatex -shell-escape -interaction=nonstopmode -output-directory="${output_dir}" "${latex_file}"
  xelatex -shell-escape -interaction=nonstopmode -output-directory="${output_dir}" "${latex_file}"
done