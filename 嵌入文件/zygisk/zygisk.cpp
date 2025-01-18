#include <cstdint>
#include <cstring>
#include <dlfcn.h>
#include <linux/bpf.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <zygisk.hpp>
#include <fstream>
#include <sstream>
#include <vector>
#include <sys/stat.h>
#include <fcntl.h>

using namespace zygisk;

class EbpfInterceptor : public ModuleBase {
public:
    void onLoad() override {
        interceptSyscall(__NR_bpf, [](SyscallContext& ctx) {
            return handleBpfSyscall(ctx);
        });
    }

private:
    static long handleBpfSyscall(SyscallContext& ctx) {
        struct utsname uts;
        uname(&uts);
        int major, minor;
        sscanf(uts.release, "%d.%d", &major, &minor);

        if (major < 5 || (major == 5 && minor < 10)) {
            return handleLegacyKernel(ctx);
        }

        return ctx.callOriginal();
    }

    static long handleLegacyKernel(SyscallContext& ctx) {
        if (getenv("ZYGISK_EMULATE_CPUFREQ")) {
            int cpu = ctx.arg<int>(0);
            unsigned int min_freq = ctx.arg<unsigned int>(1);
            unsigned int max_freq = ctx.arg<unsigned int>(2);
            
            // 检查CPU是否存在
            std::string cpu_dir = "/sys/devices/system/cpu/cpu" + std::to_string(cpu);
            if (access(cpu_dir.c_str(), F_OK) != 0) {
                return -ENODEV;
            }
            
            // 检查cpufreq是否可用
            std::string cpufreq_dir = cpu_dir + "/cpufreq";
            if (access(cpufreq_dir.c_str(), F_OK) != 0) {
                // 尝试通过sysfs直接设置
                std::string min_path = "/sys/devices/system/cpu/cpu" + std::to_string(cpu) + "/cpufreq/scaling_min_freq";
                std::string max_path = "/sys/devices/system/cpu/cpu" + std::to_string(cpu) + "/cpufreq/scaling_max_freq";
                
                if (access(min_path.c_str(), W_OK) == 0 && access(max_path.c_str(), W_OK) == 0) {
                    std::ofstream min_file(min_path);
                    std::ofstream max_file(max_path);
                    
                    if (min_file.is_open() && max_file.is_open()) {
                        min_file << min_freq;
                        max_file << max_freq;
                        return 0;
                    }
                }
                return -ENOSYS;
            }
            
            // 获取可用频率
            std::vector<unsigned int> freqs;
            std::string avail_freqs;
            std::ifstream avail_file(cpufreq_dir + "/scaling_available_frequencies");
            if (avail_file.is_open()) {
                std::string line;
                while (std::getline(avail_file, line)) {
                    std::stringstream ss(line);
                    unsigned int freq;
                    while (ss >> freq) {
                        freqs.push_back(freq);
                    }
                }
            }
            
            // 如果没有可用频率表，尝试从其他路径获取
            if (freqs.empty()) {
                std::ifstream cpuinfo_max("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq");
                std::ifstream cpuinfo_min("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq");
                
                unsigned int max, min;
                if (cpuinfo_max >> max && cpuinfo_min >> min) {
                    freqs.push_back(min);
                    freqs.push_back(max);
                }
            }
            
            // 验证频率范围
            if (!freqs.empty()) {
                std::sort(freqs.begin(), freqs.end());
                if (min_freq < freqs.front() || max_freq > freqs.back()) {
                    return -EINVAL;
                }
            }
            
            // 应用频率限制
            std::string min_path = cpufreq_dir + "/scaling_min_freq";
            std::string max_path = cpufreq_dir + "/scaling_max_freq";
            
            std::ofstream min_file(min_path);
            std::ofstream max_file(max_path);
            
            if (min_file.is_open() && max_file.is_open()) {
                min_file << min_freq;
                max_file << max_freq;
                
                // 记录当前设置
                std::string clamp_file = "/data/adb/modules/fas-rs/cpu" + std::to_string(cpu) + "_clamp";
                std::ofstream clamp(clamp_file);
                if (clamp.is_open()) {
                    clamp << min_freq << " " << max_freq;
                }
                
                return 0;
            }
            
            return -EIO;
        }
        return ctx.callOriginal();
    }
};

REGISTER_ZYGISK_MODULE(EbpfInterceptor);