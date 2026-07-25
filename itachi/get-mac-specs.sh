#!/bin/bash
# Run this ON YOUR MACBOOK (Terminal.app) to capture the specs that matter
# for sizing Itachi's models. Output goes to itachi-specs.txt — paste it
# back into the Claude session or commit it to this repo.

OUT="itachi-specs.txt"
{
  echo "=== Itachi hardware survey — $(date) ==="
  echo
  echo "--- Chip & model ---"
  sysctl -n machdep.cpu.brand_string
  system_profiler SPHardwareDataType | grep -E "Model Name|Chip|Total Number of Cores|Memory"
  echo
  echo "--- macOS version ---"
  sw_vers
  echo
  echo "--- GPU / Neural Engine ---"
  system_profiler SPDisplaysDataType | grep -E "Chipset Model|Metal"
  echo
  echo "--- Free disk (models need 5-40 GB) ---"
  df -h / | tail -1
  echo
  echo "--- Already installed? ---"
  command -v ollama >/dev/null && echo "ollama: $(ollama --version 2>/dev/null)" || echo "ollama: NOT installed"
  command -v brew   >/dev/null && echo "brew:   $(brew --version | head -1)"  || echo "brew:   NOT installed"
  command -v python3 >/dev/null && echo "python: $(python3 --version)"        || echo "python: NOT installed"
} | tee "$OUT"

echo
echo "Saved to $OUT — share this file to get model recommendations tuned to your Mac."
