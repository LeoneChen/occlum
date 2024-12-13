define hook-run
    echo Run command triggered!\n
    catch signal SIGILL
    # break only on CPUID (0fa2) and RDTSC (0f31)
    condition $bpnum *(uint16_t*)$rip == 0xa20f || *(uint16_t*)$rip == 0x310f
    commands
        silent
        # set $current_language = show language
        # set language c
    
        # # If we don't disable pagination then successive prints from this handler (even despite it's
        # # called for different events) will stop and prompt the user for continuation, which is really
        # # annoying.
        # set $pagination_was_on = (show pagination) =~ "on"
        # set pagination off
    
        # if *(uint16_t*)$rip == 0xa20f
        #     echo [occlum.gdb] Passing SIGILL caused by CPUID to the enclave\n
        # end
        # if *(uint16_t*)$rip == 0x310f
        #     echo [occlum.gdb] Passing SIGILL caused by RDTSC to the enclave\n
        # end
    
        # if $pagination_was_on
        #     set pagination on
        # else
        #     set pagination off
        # end
        # set language $current_language
        continue
    end
end
