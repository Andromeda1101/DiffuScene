#!/bin/bash
# 快速验证脚本 - 检查新功能的代码完整性

echo "========================================="
echo "验证生成优化过程视频功能的代码修改"
echo "========================================="
echo ""

# 颜色代码
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查计数
pass_count=0
fail_count=0

echo "1. 检查 utils.py 中的新函数..."
if grep -q "def save_object_info_json" scripts/utils.py; then
    echo -e "${GREEN}✓ save_object_info_json 函数存在${NC}"
    ((pass_count++))
else
    echo -e "${RED}✗ 缺少 save_object_info_json 函数${NC}"
    ((fail_count++))
fi

if grep -q "def create_video_from_frames" scripts/utils.py; then
    echo -e "${GREEN}✓ create_video_from_frames 函数存在${NC}"
    ((pass_count++))
else
    echo -e "${RED}✗ 缺少 create_video_from_frames 函数${NC}"
    ((fail_count++))
fi

echo ""
echo "2. 检查 generate_diffusion.py 中的新参数..."
if grep -q "save_progressive_video" scripts/generate_diffusion.py; then
    echo -e "${GREEN}✓ --save_progressive_video 参数存在${NC}"
    ((pass_count++))
else
    echo -e "${RED}✗ 缺少 --save_progressive_video 参数${NC}"
    ((fail_count++))
fi

if grep -q "video_num_steps" scripts/generate_diffusion.py; then
    echo -e "${GREEN}✓ --video_num_steps 参数存在${NC}"
    ((pass_count++))
else
    echo -e "${RED}✗ 缺少 --video_num_steps 参数${NC}"
    ((fail_count++))
fi

if grep -q "video_fps" scripts/generate_diffusion.py; then
    echo -e "${GREEN}✓ --video_fps 参数存在${NC}"
    ((pass_count++))
else
    echo -e "${RED}✗ 缺少 --video_fps 参数${NC}"
    ((fail_count++))
fi

echo ""
echo "3. 检查 generate_diffusion.py 中的实现逻辑..."
if grep -q "generate_layout_progressive" scripts/generate_diffusion.py; then
    echo -e "${GREEN}✓ generate_layout_progressive 调用存在${NC}"
    ((pass_count++))
else
    echo -e "${RED}✗ 缺少 generate_layout_progressive 调用${NC}"
    ((fail_count++))
fi

if grep -q "save_object_info_json" scripts/generate_diffusion.py; then
    echo -e "${GREEN}✓ save_object_info_json 函数调用存在${NC}"
    ((pass_count++))
else
    echo -e "${RED}✗ 缺少 save_object_info_json 函数调用${NC}"
    ((fail_count++))
fi

if grep -q "create_video_from_frames" scripts/generate_diffusion.py; then
    echo -e "${GREEN}✓ create_video_from_frames 函数调用存在${NC}"
    ((pass_count++))
else
    echo -e "${RED}✗ 缺少 create_video_from_frames 函数调用${NC}"
    ((fail_count++))
fi

echo ""
echo "4. 检查测试脚本..."
if [ -f "run/generate_progressive_video_test.sh" ]; then
    echo -e "${GREEN}✓ generate_progressive_video_test.sh 存在${NC}"
    ((pass_count++))
    if [ -x "run/generate_progressive_video_test.sh" ]; then
        echo -e "${GREEN}✓ 测试脚本有可执行权限${NC}"
        ((pass_count++))
    else
        echo -e "${YELLOW}⚠ 测试脚本缺少可执行权限${NC}"
        ((fail_count++))
    fi
else
    echo -e "${RED}✗ generate_progressive_video_test.sh 不存在${NC}"
    ((fail_count++))
fi

if [ -f "run/generate_progressive_video_text_test.sh" ]; then
    echo -e "${GREEN}✓ generate_progressive_video_text_test.sh 存在${NC}"
    ((pass_count++))
    if [ -x "run/generate_progressive_video_text_test.sh" ]; then
        echo -e "${GREEN}✓ 文本测试脚本有可执行权限${NC}"
        ((pass_count++))
    else
        echo -e "${YELLOW}⚠ 文本测试脚本缺少可执行权限${NC}"
        ((fail_count++))
    fi
else
    echo -e "${RED}✗ generate_progressive_video_text_test.sh 不存在${NC}"
    ((fail_count++))
fi

echo ""
echo "5. 检查文档..."
if [ -f "PROGRESSIVE_VIDEO_GUIDE.md" ]; then
    echo -e "${GREEN}✓ PROGRESSIVE_VIDEO_GUIDE.md 存在${NC}"
    ((pass_count++))
else
    echo -e "${RED}✗ PROGRESSIVE_VIDEO_GUIDE.md 不存在${NC}"
    ((fail_count++))
fi

echo ""
echo "6. 检查Python依赖..."
if python -c "import cv2" 2>/dev/null; then
    echo -e "${GREEN}✓ opencv-python 已安装${NC}"
    ((pass_count++))
elif python -c "import imageio" 2>/dev/null; then
    echo -e "${YELLOW}⚠ 使用 imageio (opencv-python 未安装但可用)${NC}"
    ((pass_count++))
else
    echo -e "${YELLOW}⚠ opencv-python 和 imageio 都未安装（视频生成将失败）${NC}"
    echo -e "  建议安装: pip install opencv-python"
fi

echo ""
echo "========================================="
echo "验证结果汇总"
echo "========================================="
echo -e "通过: ${GREEN}${pass_count}${NC}"
echo -e "失败: ${RED}${fail_count}${NC}"
echo ""

if [ $fail_count -eq 0 ]; then
    echo -e "${GREEN}所有检查通过！可以开始使用视频生成功能。${NC}"
    echo ""
    echo "使用方法："
    echo "  1. 运行测试: cd run && ./generate_progressive_video_test.sh"
    echo "  2. 查看文档: cat PROGRESSIVE_VIDEO_GUIDE.md"
    echo ""
    exit 0
else
    echo -e "${RED}存在 ${fail_count} 个问题，请检查上述错误。${NC}"
    echo ""
    exit 1
fi
