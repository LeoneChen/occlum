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

// #define KAFL
// #define PERFORM

#ifdef PERFORM
#include <time.h>
extern clock_t g_time_after_enclave_init;
#endif

#ifdef KAFL
#include "utils.h"
#include <assert.h>
#endif

int main(int argc, char *argv[]) {
#ifdef PERFORM
    clock_t time_start = clock();
#endif
#ifdef KAFL
    agent_init(1);
#endif
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
    if (occlum_pal_init(&attr) < 0) {
        return EXIT_FAILURE;
    }

    // Use Occlum PAL to execute the cmd
    struct occlum_stdio_fds io_fds = {
        .stdin_fd = STDIN_FILENO,
        .stdout_fd = STDOUT_FILENO,
        .stderr_fd = STDERR_FILENO,
    };
    int exit_status = 0;
    int libos_tid = 0;
#ifdef PERFORM
    clock_t time_after_init = clock();
#endif
#ifdef KAFL
    kAFL_payload *pbuf =
        (kAFL_payload *)malloc_resident_pages(PAYLOAD_MAX_SIZE / PAGE_SIZE);
    assert(pbuf);
    kAFL_hypercall(HYPERCALL_KAFL_GET_PAYLOAD, (uint64_t)pbuf);
    hrange_submit(0, 0x1000, 0x7fffffffffff);
    kAFL_hypercall(HYPERCALL_KAFL_USER_FAST_ACQUIRE, 0);
    hprintf("Data %p %d\n", pbuf->data, pbuf->size);
    write_to_file("./test_code", pbuf->data, pbuf->size);
#endif
    struct occlum_pal_create_process_args create_process_args = {
        .path = (const char *)
#ifdef KAFL
        "/host/test_code"
#else
        cmd_path
#endif
        ,
        .argv = (const char **) cmd_args,
        .env = environ,
        .stdio = (const struct occlum_stdio_fds *) &io_fds,
        .pid = &libos_tid,
    };
    if (occlum_pal_create_process(&create_process_args) < 0) {
        // Command not found or other internal errors
#ifdef KAFL
        hprintf("occlum_pal_create_process fail\n");
        goto fuzz_end;
#endif
        return 127;
    }

    struct occlum_pal_exec_args exec_args = {
        .pid = libos_tid,
        .exit_value = &exit_status,
    };
    if (occlum_pal_exec(&exec_args) < 0) {
        // Command not found or other internal errors
#ifdef KAFL
        hprintf("occlum_pal_exec fail\n");
        goto fuzz_end;
#endif
        return 127;
    }
#ifdef PERFORM
    clock_t time_after_exec = clock();
#endif
#ifdef KAFL
    goto fuzz_end;
#endif

    // Convert the exit status to a value in a shell-like encoding
    if (WIFEXITED(exit_status)) { // terminated normally
        exit_status = WEXITSTATUS(exit_status) & 0x7F; // [0, 127]
    } else { // killed by signal
        exit_status = 128 + WTERMSIG(exit_status); // [128 + 1, 128 + 64]
    }

    // Destroy Occlum PAL
    occlum_pal_destroy();
#ifdef PERFORM
    clock_t time_after_destroy = clock();
    double enclave_init_time = (double)(g_time_after_enclave_init - time_start) /
                               CLOCKS_PER_SEC;
    double libos_init_time = (double)(time_after_init - g_time_after_enclave_init) /
                             CLOCKS_PER_SEC;
    double exec_time = (double)(time_after_exec - time_after_init) / CLOCKS_PER_SEC;
    double destroy_time = (double)(time_after_destroy - time_after_exec) / CLOCKS_PER_SEC;
    printf("Initialization time of Enclave: %f s\n", enclave_init_time);
    printf("Initialization time of LibOS: %f s\n", libos_init_time);
    printf("Running time of target (e.g. Hello World): %f s\n", exec_time);
    printf("Destruction time of Enclave and LibOS: %f s\n", destroy_time);
#endif

    return exit_status;
#ifdef KAFL
fuzz_end:
    hprintf("Before HYPERCALL_KAFL_RELEASE\n");
    kAFL_hypercall(HYPERCALL_KAFL_RELEASE, 0);
    hprintf("Shouldn't reach here\n");
    return -1;
#endif
}
