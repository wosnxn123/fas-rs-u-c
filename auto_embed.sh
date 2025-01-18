#!/bin/bash

# 配置参数
readonly INPUT_DIR="输入文件"
readonly EMBED_DIR="嵌入文件"
readonly OUTPUT_DIR="输出文件"

# 日志级别定义
readonly LOG_LEVEL_INFO="INFO"
readonly LOG_LEVEL_WARNING="WARNING"
readonly LOG_LEVEL_ERROR="ERROR"

# 日志函数
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# 错误处理函数
handle_error() {
    log "$LOG_LEVEL_ERROR" "错误：$1 (文件: $0, 行号: $2)"
    exit 1
}

# 创建必要目录
mkdir -p "$OUTPUT_DIR" || handle_error "无法创建输出目录"

# 检查输入文件
if [ ! -d "$INPUT_DIR" ]; then
    handle_error "输入目录不存在"
fi

# 处理输入文件
for file in "$INPUT_DIR"/*.zip; do
    # 获取文件名
    base_name=$(basename "$file" .zip)
    
    # 创建临时工作目录
    work_dir="$OUTPUT_DIR/$base_name"
    mkdir -p "$work_dir" || handle_error "无法创建临时工作目录"
    
    # 解压输入文件
    log "$LOG_LEVEL_INFO" "正在解压文件：$file"
    if [[ "$file" == *.gz ]]; then
        if command -v unpigz &> /dev/null; then
            if ! unpigz -c "$file" | tar -x -C "$work_dir"; then
                handle_error "无法解压文件 $file" $LINENO
            fi
        else
            if ! gunzip -c "$file" | tar -x -C "$work_dir"; then
                handle_error "无法解压文件 $file" $LINENO
            fi
        fi
    elif [[ "$file" == *.zip ]]; then
        if ! unzip -qo "$file" -d "$work_dir"; then
            handle_error "无法解压文件 $file" $LINENO
        fi
    else
        handle_error "不支持的文件格式：$file" $LINENO
    fi
    log "$LOG_LEVEL_INFO" "文件解压完成"
    
    # 执行嵌入操作
    if [ -d "$EMBED_DIR" ]; then
        log "$LOG_LEVEL_INFO" "正在嵌入文件"
        cp -r "$EMBED_DIR"/* "$work_dir/" || handle_error "文件嵌入失败" $LINENO
    fi
    
    # 打包处理后的文件
    output_file="$base_name"_embedded.zip
    log "$LOG_LEVEL_INFO" "正在打包文件：$output_file"
    if ! (cd "$work_dir" && zip -r "$output_file" ./*); then
        handle_error "打包失败" $LINENO
    fi
    
    # 移动输出文件
    if [ -f "$work_dir/$output_file" ]; then
        mv "$work_dir/$output_file" "$OUTPUT_DIR/" || handle_error "无法移动输出文件"
        log "输出文件已保存到：$OUTPUT_DIR/$output_file"
    else
        handle_error "输出文件 $output_file 未找到"
    fi
    
    # 清理临时工作目录
    rm -rf "$work_dir" || handle_error "无法清理临时工作目录"
done

log "所有文件处理完成"
exit 0