#include <linux/limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <libgen.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <occlum_pal_api.h>
#include <sys/prctl.h>
#include "utils.h"
#include <assert.h>

int _main(int argc, char *argv[]) {
    // Parse arguments
    if (argc < 2) {
        fprintf(stderr, "[ERROR] occlum-run: at least one argument must be provided\n\n");
        fprintf(stderr, "Usage: occlum-run <executable> [<args>]\n");
        return EXIT_FAILURE;
    }

    char **cmd_args = &argv[1];
    char *cmd_path = strdup(argv[1]);
    extern const char **environ;

    // Change cmd_args[0] from program path to program name in place (e.g., "/bin/abc" to "abc")
    char *cmd_path_tmp = strdup(cmd_path);
    const char *program_name = (const char *) basename(cmd_path_tmp);
    memset(cmd_args[0], 0, strlen(cmd_args[0]));
    memcpy(cmd_args[0], program_name, strlen(program_name));

    // Check Occlum PAL version
    int pal_version = occlum_pal_get_version();
    if (pal_version <= 0) {
        return EXIT_FAILURE;
    }

    // Init Occlum PAL
    struct occlum_pal_attr attr = OCCLUM_PAL_ATTR_INITVAL;
    attr.log_level = getenv("OCCLUM_LOG_LEVEL");
    hprintf("Before occlum_pal_init\n");
    if (occlum_pal_init(&attr) < 0) {
        hprintf("occlum_pal_init fail\n");
        return EXIT_FAILURE;
    }
    hprintf("occlum_pal_init success\n");

    // Use Occlum PAL to execute the cmd
    struct occlum_stdio_fds io_fds = {
        .stdin_fd = STDIN_FILENO,
        .stdout_fd = STDOUT_FILENO,
        .stderr_fd = STDERR_FILENO,
    };
    int exit_status = 0;
    int libos_tid = 0;
    struct occlum_pal_create_process_args create_process_args = {
        .path = (const char *) "/host/test_code",
        .argv = (const char **) cmd_args,
        .env = environ,
        .stdio = (const struct occlum_stdio_fds *) &io_fds,
        .pid = &libos_tid,
    };
    hprintf("Before occlum_pal_create_process\n");
    if (occlum_pal_create_process(&create_process_args) < 0) {
        // Command not found or other internal errors
        hprintf("occlum_pal_create_process fail\n");
        return 127;
    }

    struct occlum_pal_exec_args exec_args = {
        .pid = libos_tid,
        .exit_value = &exit_status,
    };
    hprintf("Before occlum_pal_exec\n");
    if (occlum_pal_exec(&exec_args) < 0) {
        // Command not found or other internal errors
        hprintf("occlum_pal_exec fail\n");
        return 127;
    }

    // Convert the exit status to a value in a shell-like encoding
    if (WIFEXITED(exit_status)) { // terminated normally
        exit_status = WEXITSTATUS(exit_status) & 0x7F; // [0, 127]
    } else { // killed by signal
        exit_status = 128 + WTERMSIG(exit_status); // [128 + 1, 128 + 64]
    }

    // Destroy Occlum PAL
    hprintf("Before occlum_pal_destroy\n");
    occlum_pal_destroy();

    return exit_status;
}

int main(int argc, char **argv) {
    agent_init(1);

    // Register payload buffer
    kAFL_payload *pbuf =
        (kAFL_payload *)malloc_resident_pages(PAYLOAD_MAX_SIZE / PAGE_SIZE);
    assert(pbuf);
    kAFL_hypercall(HYPERCALL_KAFL_GET_PAYLOAD, (uint64_t)pbuf);
    hrange_submit(0, 0x1000, 0x7fffffffffff);

    while (1) {
        kAFL_hypercall(HYPERCALL_KAFL_USER_FAST_ACQUIRE, 0);
        hprintf("Data %p %d\n", pbuf->data, pbuf->size);
        write_to_file("./test_code", pbuf->data, pbuf->size);
        hprintf("Before main\n");
        _main(argc, argv);
        hprintf("After main\n");
        kAFL_hypercall(HYPERCALL_KAFL_RELEASE, 0);
        hprintf("Round finish\n");
    }
}
