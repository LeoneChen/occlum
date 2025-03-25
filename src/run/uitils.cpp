#include <errno.h>
#include <sys/stat.h>
#include <string>
#include "fmt/format.h"
#include "utils.h"
#include <fstream>
#include <filesystem>
#include <sys/stat.h>

namespace fs = std::filesystem;

void hperror(const std::string &err_msg) {
    hprintf("%s: %s\n", err_msg.c_str(), strerror(errno));
}

void write_to_file(const char *filename, const uint8_t *data, size_t size) {
    std::ofstream file(filename, std::ios::out | std::ios::binary);
    if (file.is_open()) {
        file.write((const char *)data, size);
    } else {
        hperror(fmt::format("fopen {}", filename));
    }
    file.close();

    if (chmod(filename, 0755) != 0) {
        hperror(fmt::format("chmod {}", filename));
    }
}

char *shell_exec(const char *cmd) {
    hprintf("$ %s\n", cmd);
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd, "r"), pclose);
    if (pipe) {
        std::array<char, 128> buffer;
        std::string result;
        while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
            result += buffer.data();
        }
        return strdup(result.c_str());
    } else {
        hperror("popen() failed!");
        return nullptr;
    }
}

int agent_init(int verbose) {
    host_config_t host_config;

    // set ready state
    kAFL_hypercall(HYPERCALL_KAFL_ACQUIRE, 0);
    kAFL_hypercall(HYPERCALL_KAFL_RELEASE, 0);

    get_nyx_cpu_type();

    kAFL_hypercall(HYPERCALL_KAFL_GET_HOST_CONFIG, (uintptr_t)&host_config);

    if (verbose) {
        fprintf(stderr, "GET_HOST_CONFIG\n");
        fprintf(stderr, "\thost magic:  0x%x, version: 0x%x\n",
                host_config.host_magic, host_config.host_version);
        fprintf(stderr, "\tbitmap size: 0x%x, ijon:    0x%x\n",
                host_config.bitmap_size, host_config.ijon_bitmap_size);
        fprintf(stderr, "\tpayload size: %u KB\n",
                host_config.payload_buffer_size / 1024);
        fprintf(stderr, "\tworker id: %d\n", host_config.worker_id);
    }

    if (host_config.host_magic != NYX_HOST_MAGIC) {
        hprintf("HOST_MAGIC mismatch: %08x != %08x\n",
                host_config.host_magic, NYX_HOST_MAGIC);
        habort("HOST_MAGIC mismatch!");
        return -1;
    }

    if (host_config.host_version != NYX_HOST_VERSION) {
        hprintf("HOST_VERSION mismatch: %08x != %08x\n",
                host_config.host_version, NYX_HOST_VERSION);
        habort("HOST_VERSION mismatch!");
        return -1;
    }

    if (host_config.payload_buffer_size > PAYLOAD_MAX_SIZE) {
        hprintf("Fuzzer payload size too large: %lu > %lu\n",
                host_config.payload_buffer_size, PAYLOAD_MAX_SIZE);
        habort("Host payload size too large!");
        return -1;
    }

    agent_config_t agent_config = {0};
    agent_config.agent_magic = NYX_AGENT_MAGIC;
    agent_config.agent_version = NYX_AGENT_VERSION;
    // agent_config.agent_timeout_detection = 0; // timeout by host
    // agent_config.agent_tracing = 0; // trace by host
    // agent_config.agent_ijon_tracing = 0; // no IJON
    agent_config.agent_non_reload_mode = 0; // no persistent mode
    // agent_config.trace_buffer_vaddr = 0xdeadbeef;
    // agent_config.ijon_trace_buffer_vaddr = 0xdeadbeef;
    agent_config.coverage_bitmap_size = host_config.bitmap_size;
    // agent_config.input_buffer_size;
    // agent_config.dump_payloads; // set by hypervisor (??)

    kAFL_hypercall(HYPERCALL_KAFL_SET_AGENT_CONFIG,
                   (uintptr_t)&agent_config);

    return 0;
}