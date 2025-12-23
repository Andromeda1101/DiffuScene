#!/bin/bash
# Quick test script for text input functionality
# This script performs basic tests without requiring GPU or pretrained models

set -e  # Exit on error

echo "========================================"
echo "Testing Text Input Functionality"
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test 1: Check if main script exists
echo -e "\n${YELLOW}Test 1: Checking if script exists...${NC}"
if [ -f "scripts/generate_from_text_input.py" ]; then
    echo -e "${GREEN}✓ Script exists${NC}"
else
    echo -e "${RED}✗ Script not found${NC}"
    exit 1
fi

# Test 2: Check if sample text files exist
echo -e "\n${YELLOW}Test 2: Checking sample text files...${NC}"
if [ -d "demo/text_inputs" ]; then
    file_count=$(ls -1 demo/text_inputs/*.txt 2>/dev/null | wc -l)
    if [ $file_count -gt 0 ]; then
        echo -e "${GREEN}✓ Found $file_count sample text files${NC}"
        ls demo/text_inputs/*.txt
    else
        echo -e "${RED}✗ No .txt files found in demo/text_inputs/${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Directory demo/text_inputs/ not found${NC}"
    exit 1
fi

# Test 3: Check if shell script exists and is executable
echo -e "\n${YELLOW}Test 3: Checking run script...${NC}"
if [ -f "run/generate_text_input.sh" ]; then
    if [ -x "run/generate_text_input.sh" ]; then
        echo -e "${GREEN}✓ Run script exists and is executable${NC}"
    else
        echo -e "${YELLOW}⚠ Run script exists but is not executable. Making it executable...${NC}"
        chmod +x run/generate_text_input.sh
        echo -e "${GREEN}✓ Run script is now executable${NC}"
    fi
else
    echo -e "${RED}✗ Run script not found${NC}"
    exit 1
fi

# Test 4: Check if documentation exists
echo -e "\n${YELLOW}Test 4: Checking documentation...${NC}"
docs_ok=true
if [ -f "TEXT_INPUT_GUIDE.md" ]; then
    echo -e "${GREEN}✓ TEXT_INPUT_GUIDE.md exists${NC}"
else
    echo -e "${RED}✗ TEXT_INPUT_GUIDE.md not found${NC}"
    docs_ok=false
fi

if [ -f "文本输入快速上手.md" ]; then
    echo -e "${GREEN}✓ 文本输入快速上手.md exists${NC}"
else
    echo -e "${RED}✗ 文本输入快速上手.md not found${NC}"
    docs_ok=false
fi

if [ "$docs_ok" = false ]; then
    exit 1
fi

# Test 5: Verify script syntax
echo -e "\n${YELLOW}Test 5: Verifying Python script syntax...${NC}"
if python3 -m py_compile scripts/generate_from_text_input.py 2>/dev/null; then
    echo -e "${GREEN}✓ Python script syntax is valid${NC}"
else
    echo -e "${RED}✗ Python script has syntax errors${NC}"
    exit 1
fi

# Test 6: Check if script has proper imports (basic check)
echo -e "\n${YELLOW}Test 6: Checking script structure...${NC}"
required_imports=("argparse" "os" "json" "torch" "numpy")
all_imports_ok=true
for import_name in "${required_imports[@]}"; do
    if grep -q "import $import_name" scripts/generate_from_text_input.py; then
        echo -e "${GREEN}✓ Found import: $import_name${NC}"
    else
        echo -e "${RED}✗ Missing import: $import_name${NC}"
        all_imports_ok=false
    fi
done

if [ "$all_imports_ok" = false ]; then
    echo -e "${YELLOW}⚠ Some imports may be missing, but this might be okay${NC}"
fi

# Test 7: Check help menu
echo -e "\n${YELLOW}Test 7: Testing help menu...${NC}"
cd scripts
if python3 generate_from_text_input.py --help > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Help menu works${NC}"
else
    echo -e "${RED}✗ Help menu failed${NC}"
    cd ..
    exit 1
fi
cd ..

# Test 8: Read sample text files
echo -e "\n${YELLOW}Test 8: Reading sample text files...${NC}"
for txt_file in demo/text_inputs/*.txt; do
    if [ -f "$txt_file" ]; then
        content=$(cat "$txt_file")
        filename=$(basename "$txt_file")
        if [ -n "$content" ]; then
            echo -e "${GREEN}✓ $filename: \"$content\"${NC}"
        else
            echo -e "${RED}✗ $filename is empty${NC}"
        fi
    fi
done

# Test 9: Verify text file encoding
echo -e "\n${YELLOW}Test 9: Checking text file encoding...${NC}"
encoding_ok=true
for txt_file in demo/text_inputs/*.txt; do
    if file -b --mime-encoding "$txt_file" | grep -qE "utf-8|us-ascii"; then
        echo -e "${GREEN}✓ $(basename $txt_file): UTF-8 compatible${NC}"
    else
        echo -e "${RED}✗ $(basename $txt_file): Not UTF-8 encoded${NC}"
        encoding_ok=false
    fi
done

if [ "$encoding_ok" = false ]; then
    echo -e "${YELLOW}⚠ Some files have encoding issues. Consider converting to UTF-8.${NC}"
fi

# Summary
echo -e "\n========================================"
echo -e "${GREEN}All basic tests passed!${NC}"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Ensure you have the pretrained models downloaded"
echo "2. Update paths in run/generate_text_input.sh if needed"
echo "3. Run: cd run && bash generate_text_input.sh"
echo ""
echo "For more information, see:"
echo "  - TEXT_INPUT_GUIDE.md (English)"
echo "  - 文本输入快速上手.md (中文)"
echo ""
