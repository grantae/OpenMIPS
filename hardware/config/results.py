#!/usr/bin/python

# A simple test harness that runs a specified set of executables
# and checks their output files. Each individual test passes if
# its output file reads '1' and fails otherwise.
#
# Author: Grant Ayers (ayers@cs.stanford.edu)

import argparse

class colors:
    RED   = '\033[31m'
    GREEN = '\033[32m'
    DEFAULT = '\33[39m'

def parse_results(args):
    results_file = open(args.results)
    results_str = ''
    results_passed = 0
    results_failed = 0
    for line in sorted(results_file):
        columns = line.split(' ')
        if len(columns) >= 2:
            if (columns[1][0] == '1'):
                results_passed += 1
                res_str = colors.GREEN + 'PASS' + colors.DEFAULT
            else:
                results_failed += 1
                res_str = colors.RED + 'FAIL' + colors.DEFAULT
            results_str += "{0}: {1}\n".format(columns[0].ljust(25), res_str)
    results_file.close()
    return (results_str, results_passed, results_failed)

def display_results(results):
    passed = results[1]
    failed = results[2]
    total  = passed + failed
    print 'Test Results:\n'
    print results[0]
    if (failed > 0):
        print '{0} {1} failed.'.format(failed, ('tests' if (failed > 1) else 'test'))
    else:
        print '{0} {1} passed.'.format(passed, ('tests' if (passed > 1) else 'test'))

def main():
    desc = "MIPS test harness: Reports the results of a set of tests."
    cl_parser = argparse.ArgumentParser(description=desc)
    cl_parser.add_argument('-r', '--results', help='Test result file to report', metavar='')
    cl_args = cl_parser.parse_args()
    display_results(parse_results(cl_args))

if __name__ == '__main__':
    main()
