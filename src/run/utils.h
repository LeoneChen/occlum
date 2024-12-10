#pragma once

#define PAYLOAD_MAX_SIZE (1 * 1024 * 1024)

#ifdef __cplusplus
extern "C"
{
#endif

#include "nyx_api.h"
#include "nyx_agent.h"

    void write_to_file(const char *filename, const uint8_t *data, size_t size);
    // caller should free the returned string
    char *shell_exec(const char *cmd);
    int agent_init(int verbose);

#ifdef __cplusplus
}
#endif