#!/bin/bash

# 配置参数
INPUT_DIR="输入文件"
EMBED_DIR="嵌入文件"
OUTPUT_DIR="输出文件"

# 创建必要目录
mkdir -p "$OUTPUT_DIR"

# 处理输入文件
for file in "$INPUT_DIR"/*.zip; do
    # 获取文件名
    base_name=$(basename "$file" .zip)
    
    # 创建临时工作目录
    work_dir="$OUTPUT_DIR/$base_name"
    mkdir -p "$work_dir"
    
    # 解压输入文件
    if ! unzip -qo "$file" -d "$work_dir"; then
        echo "错误：无法解压文件 $file"
        continue
    fi
    
    # 执行嵌入操作
    if [ -d "$EMBED_DIR" ]; then
        cp -r "$EMBED_DIR"/* "$work_dir/"
    fi
    
    # 打包处理后的文件
    output_file="$base_name"_embedded.zip
    if ! (cd "$work_dir" && zip -r "$output_file" ./*); then
        echo "错误：打包失败"
        continue
    fi
    
    # 移动输出文件
    if [ -f "$work_dir/$output_file" ]; then
        mv "$work_dir/$output_file" "$OUTPUT_DIR/"
        echo "输出文件已保存到：$OUTPUT_DIR/$output_file"
    else
        echo "警告：输出文件 $output_file 未找到"
    fi
    
    # 清理临时工作目录
    rm -rf "$work_dir"
done

echo "所有文件处理完成"