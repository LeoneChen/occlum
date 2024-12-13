import argparse
import re
import json
import sys


def clear_empty_item(collect_dict):
    syscall_to_delete = []
    for syscall_name, testcase_dict in collect_dict.items():
        testcase_to_delete = []
        for testcase_name, log in testcase_dict.items():
            if not log:
                testcase_to_delete.append(testcase_name)
        for testcase_name in testcase_to_delete:
            testcase_dict.pop(testcase_name)
        if not testcase_dict:
            syscall_to_delete.append(syscall_name)
    for syscall_name in syscall_to_delete:
        collect_dict.pop(syscall_name)
    return collect_dict


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input", type=str, help="input file")
    parser.add_argument(
        "-o", "--output_dir", type=str, help="output directory", default="."
    )
    args = parser.parse_args()

    success_dict = {}
    fail_dict = {}
    skip_dict = {}
    with open(args.input, "r") as f:
        syscall_name = None
        testcase_name = None
        log = []
        for line in f:
            testcase_match = re.match(
                r"INFO:\s*Test case:\s*(\w*)",
                line,
            )
            if testcase_match:
                # update last round
                if syscall_name and testcase_name:
                    log_str = "\n".join(log)
                    if re.search(
                        r"Summary.*?(failed|broken|warnings)\s*[^0]", log_str, re.DOTALL
                    ) or re.search("(TFAIL|TBROK|TWARN)", log_str):
                        fail_dict.setdefault(syscall_name, {})[
                            testcase_name
                        ] = log_str.strip().split("\n")
                    elif re.search(r"Summary.*?skip\s*[^0]", log_str, re.DOTALL):
                        skip_dict.setdefault(syscall_name, {})[
                            testcase_name
                        ] = log_str.strip().split("\n")
                    else:
                        success_dict.setdefault(syscall_name, {})[
                            testcase_name
                        ] = log_str.strip().split("\n")

                # new round
                testcase_name = testcase_match.group(1)
                syscall_match = re.match(r"\D*", testcase_name)
                syscall_name = (
                    syscall_match.group(0) if syscall_match else testcase_name
                )
                log = []
            else:
                log.append(line.strip())

    # clear empty item
    success_dict = clear_empty_item(success_dict)
    fail_dict = clear_empty_item(fail_dict)
    skip_dict = clear_empty_item(skip_dict)

    print(f"{success_dict.keys()} {len(success_dict)}")
    with open(f"{args.output_dir}/success.json", "w") as f:
        f.write(json.dumps(success_dict, indent=4, sort_keys=True))

    print(f"{fail_dict.keys()} {len(fail_dict)}")
    with open(f"{args.output_dir}/fail.json", "w") as f:
        f.write(json.dumps(fail_dict, indent=4, sort_keys=True))

    print(f"{skip_dict.keys()} {len(skip_dict)}")
    with open(f"{args.output_dir}/skip.json", "w") as f:
        f.write(json.dumps(skip_dict, indent=4, sort_keys=True))


if __name__ == "__main__":
    main()
