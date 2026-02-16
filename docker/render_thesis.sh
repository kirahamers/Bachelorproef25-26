for latex_file in ${source_files}; do
  filename=$(basename "${latex_file}" .tex)
  echo "========== Compiling ${filename} =========="
  
  # 1. First XeLaTeX pass (always required)
  xelatex -shell-escape -interaction=nonstopmode -output-directory="${output_dir}" "${latex_file}"
  
  # 2. Only run Biber if the .bcf file exists (skips poster if no bib)
  if [ -f "${output_dir}/${filename}.bcf" ]; then
    echo "Running Biber for ${filename}..."
    biber --input-directory "${output_dir}" --output-directory "${output_dir}" "${filename}"
    
    # Run XeLaTeX again to include references
    xelatex -shell-escape -interaction=nonstopmode -output-directory="${output_dir}" "${latex_file}"
  else
    echo "No bibliography metadata found for ${filename}, skipping Biber."
  fi

  # Final pass for Table of Contents/Layout
  xelatex -shell-escape -interaction=nonstopmode -output-directory="${output_dir}" "${latex_file}"
done