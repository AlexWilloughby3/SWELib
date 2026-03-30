/*
 * swelib_docker.c — C shim for executing Docker CLI commands.
 *
 * Runs `docker` via fork/exec and captures stdout/stderr.
 * Same pattern as swelib_syscalls.c process execution.
 */

#include <lean/lean.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <errno.h>

/*
 * swelib_docker_exec : bin : @& String → args : @& Array String → IO (Except String String)
 *
 * Executes the docker binary with the given arguments.
 * Returns Ok(stdout) on exit code 0, or Error(stderr) otherwise.
 */
LEAN_EXPORT lean_obj_res swelib_docker_exec(
    b_lean_obj_arg bin_obj, b_lean_obj_arg args_obj,
    lean_obj_arg world
) {
    const char *bin = lean_string_cstr(bin_obj);

    /* Build argv: [bin, args..., NULL] */
    size_t argc = lean_array_size(args_obj);
    const char **argv = malloc((argc + 2) * sizeof(char *));
    if (!argv) {
        lean_object *err = lean_mk_string("docker_exec: allocation failed");
        lean_object *except = lean_alloc_ctor(1, 1, 0);  /* Except.error */
        lean_ctor_set(except, 0, err);
        return lean_io_result_mk_ok(except);
    }

    argv[0] = bin;
    for (size_t i = 0; i < argc; i++) {
        lean_object *s = lean_array_get_core(args_obj, i);
        argv[i + 1] = lean_string_cstr(s);
    }
    argv[argc + 1] = NULL;

    /* Create pipes for stdout and stderr */
    int stdout_pipe[2], stderr_pipe[2];
    if (pipe(stdout_pipe) != 0 || pipe(stderr_pipe) != 0) {
        free(argv);
        lean_object *err = lean_mk_string("docker_exec: pipe() failed");
        lean_object *except = lean_alloc_ctor(1, 1, 0);
        lean_ctor_set(except, 0, err);
        return lean_io_result_mk_ok(except);
    }

    pid_t pid = fork();
    if (pid < 0) {
        free(argv);
        close(stdout_pipe[0]); close(stdout_pipe[1]);
        close(stderr_pipe[0]); close(stderr_pipe[1]);
        lean_object *err = lean_mk_string("docker_exec: fork() failed");
        lean_object *except = lean_alloc_ctor(1, 1, 0);
        lean_ctor_set(except, 0, err);
        return lean_io_result_mk_ok(except);
    }

    if (pid == 0) {
        /* Child: redirect stdout/stderr and exec */
        close(stdout_pipe[0]);
        close(stderr_pipe[0]);
        dup2(stdout_pipe[1], STDOUT_FILENO);
        dup2(stderr_pipe[1], STDERR_FILENO);
        close(stdout_pipe[1]);
        close(stderr_pipe[1]);

        execvp(bin, (char *const *)argv);
        _exit(127);  /* exec failed */
    }

    /* Parent: read output */
    close(stdout_pipe[1]);
    close(stderr_pipe[1]);
    free(argv);

    /* Read stdout */
    char *stdout_buf = NULL;
    size_t stdout_len = 0;
    {
        size_t cap = 4096;
        stdout_buf = malloc(cap);
        ssize_t n;
        while ((n = read(stdout_pipe[0], stdout_buf + stdout_len, cap - stdout_len)) > 0) {
            stdout_len += (size_t)n;
            if (stdout_len >= cap) {
                cap *= 2;
                stdout_buf = realloc(stdout_buf, cap);
            }
        }
        stdout_buf[stdout_len] = '\0';
    }
    close(stdout_pipe[0]);

    /* Read stderr */
    char *stderr_buf = NULL;
    size_t stderr_len = 0;
    {
        size_t cap = 4096;
        stderr_buf = malloc(cap);
        ssize_t n;
        while ((n = read(stderr_pipe[0], stderr_buf + stderr_len, cap - stderr_len)) > 0) {
            stderr_len += (size_t)n;
            if (stderr_len >= cap) {
                cap *= 2;
                stderr_buf = realloc(stderr_buf, cap);
            }
        }
        stderr_buf[stderr_len] = '\0';
    }
    close(stderr_pipe[0]);

    /* Wait for child */
    int status;
    waitpid(pid, &status, 0);

    lean_object *except;
    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
        /* Success: return stdout */
        lean_object *result = lean_mk_string(stdout_buf);
        except = lean_alloc_ctor(0, 1, 0);  /* Except.ok */
        lean_ctor_set(except, 0, result);
    } else {
        /* Failure: return stderr (or stdout if stderr empty) */
        const char *msg = stderr_len > 0 ? stderr_buf : stdout_buf;
        lean_object *err = lean_mk_string(msg);
        except = lean_alloc_ctor(1, 1, 0);  /* Except.error */
        lean_ctor_set(except, 0, err);
    }

    free(stdout_buf);
    free(stderr_buf);

    return lean_io_result_mk_ok(except);
}
