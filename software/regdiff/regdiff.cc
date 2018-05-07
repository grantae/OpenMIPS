// regdiff.cc:
//
// A utility for comparing the MIPS architectural state between two executions.
// Written in C++14 for Unix.
//
// Copyright 2018 by Grant Ayers.
// Licensed under LGPL v3 (http://gnu.org/licenses/lgpl-3.0.en.html)
//
// In A/B tests of millions or more instructions, it can be difficult to
// pinpoint where the two executions diverge. This utility will locate the
// exact instruction where this occurs as well as which register(s) differed.
// This will work even if the two tests have different cycle counts, e.g., if
// one had a cache disabled.
//
// This program is used in conjunction with the macro (instruction-level)
// testsuite. To generate register dumps for inputs, use the 'rtrace_' target,
// e.g., 'make rtrace_mytest1' and 'make rtrace_mytest2'.
//
#include <iostream>
#include <fstream>
#include <memory>
#include <string>
#include <unistd.h>
#include <unordered_set>
#include <vector>

using std::cout;
using std::endl;
using std::ifstream;
using std::make_unique;
using std::string;
using std::unique_ptr;
using std::unordered_set;
using std::vector;

static constexpr uint64_t TOKENS = 34;

static unique_ptr<vector<uint64_t>> splitLine(ifstream &_input) {
  auto list = make_unique<vector<uint64_t>>();
  string line;
  if (!std::getline(_input, line)) {
    return list;
  }
  string ss;  // NOTE: Benchmarks with ostringstream were slower: Using string
  bool first_token = true;

  try {
    for (uint64_t i = 0; i < line.size(); i++) {
      char byte = line[i];
      if (byte == '=') {
        ss.clear();
      } else if (byte == ' ') {
        if (first_token) {
          list->push_back(std::stoul(ss, nullptr, 10));
          first_token = false;
        } else {
          list->push_back(std::stoul(ss, nullptr, 16));
        }
        ss.clear();
      } else {
        ss += byte;
      }
    }
    // The last byte has been read but there's no terminating value
    list->push_back(std::stoul(ss, nullptr, 16));
  }
  catch (std::exception e) {
    cout << "Conversion error: Unexpected string '" << ss << "'" << endl;
    list->clear();
  }

  if (list->size() != TOKENS) {
    cout << "Could not parse line '" << line << "'" << endl;
    list->clear();
  }
  return list;
}

static const char *labelForIndex(int _index) {
  switch (_index) {
    case 0: return "cycle";
    case 1: return "at";
    case 2: return "v0";
    case 3: return "v1";
    case 4: return "a0";
    case 5: return "a1";
    case 6: return "a2";
    case 7: return "a3";
    case 8: return "t0";
    case 9: return "t1";
    case 10: return "t2";
    case 11: return "t3";
    case 12: return "t4";
    case 13: return "t5";
    case 14: return "t6";
    case 15: return "t7";
    case 16: return "s0";
    case 17: return "s1";
    case 18: return "s2";
    case 19: return "s3";
    case 20: return "s4";
    case 21: return "s5";
    case 22: return "s6";
    case 23: return "s7";
    case 24: return "t8";
    case 25: return "t9";
    case 26: return "k0";
    case 27: return "k1";
    case 28: return "gp";
    case 29: return "sp";
    case 30: return "fp";
    case 31: return "ra";
    case 32: return "hi";
    case 33: return "lo";
    default: return "INVALID";
  }
}

static int indexForLabel(const string &_label) {
  // First character is {a,f,g,h,k,l,r,s,t,v}
  // Second character is {0-9,a,i,o,p,t}
  int idx = -1;
  if (_label.size() != 2) {
    return idx;
  }
  switch (_label[0]) {
    case 'a':
      switch (_label[1]) {
        case '0':
          idx = 4;
          break;
        case '1':
          idx = 5;
          break;
        case '2':
          idx = 6;
          break;
        case '3':
          idx = 7;
          break;
        case 't':
          idx = 1;
          break;
        default:
          break;
      }
      break;
    case 'f':
      idx = 30;
      break;
    case 'g':
      idx = 28;
      break;
    case 'h':
      idx = 32;
      break;
    case 'k':
      if (_label[1] == '0') {
        idx = 26;
      } else if (_label[1] == '1') {
        idx = 27;
      }
      break;
    case 'l':
      idx = 33;
      break;
    case 'r':
      idx = 31;
      break;
    case 's':
      switch (_label[1]) {
        case '0':
          idx = 16;
          break;
        case '1':
          idx = 17;
          break;
        case '2':
          idx = 18;
          break;
        case '3':
          idx = 19;
          break;
        case '4':
          idx = 20;
          break;
        case '5':
          idx = 21;
          break;
        case '6':
          idx = 22;
          break;
        case '7':
          idx = 23;
          break;
        default:
          break;
      }
      break;
    case 't':
      switch (_label[1]) {
        case '0':
          idx = 8;
          break;
        case '1':
          idx = 9;
          break;
        case '2':
          idx = 10;
          break;
        case '3':
          idx = 11;
          break;
        case '4':
          idx = 12;
          break;
        case '5':
          idx = 13;
          break;
        case '6':
          idx = 14;
          break;
        case '7':
          idx = 15;
          break;
        case '8':
          idx = 24;
          break;
        case '9':
          idx = 25;
          break;
        default:
          break;
      }
      break;
    case 'v':
      if (_label[1] == '0') {
        idx = 2;
      } else if (_label[1] == '1') {
        idx = 3;
      }
      break;
    default:
      break;
  }
  return idx;
}

static bool regdiff(ifstream &_input_a, ifstream &_input_b, uint64_t _offset, const unordered_set<int> &_excludes) {
  string line;
  bool found_diff = false;
  uint64_t inst_count = 0;
  bool valid = true;
  while (valid) {
    auto list_a = splitLine(_input_a);
    auto list_b = splitLine(_input_b);
    valid &= (list_a->size() == TOKENS && list_b->size() == TOKENS);
    if (valid) {
      if (_offset <= inst_count) {
        for (uint64_t i = 1; i < list_a->size() - 1; i++) {
          if (((*list_a)[i] != (*list_b)[i]) && (_excludes.count(static_cast<uint64_t>(i)) == 0)) {
            if (!found_diff) {
              cout << "Difference at instruction " << inst_count << " cycle "
                   << (*list_a)[0] << " (A) / " << (*list_b)[0] << " (B):" << endl;
              found_diff = true;
            }
            cout << "  " << labelForIndex(i) << ": 0x" << std::hex << (*list_a)[i]
                 << " / 0x" << (*list_b)[i] << std::dec << endl;
          }
        }
      }
      inst_count++;
      if (found_diff) {
        return true;
      }
    }
  }
  if (!found_diff && inst_count > 0) {
    uint64_t compare_count = inst_count - _offset;
    if (_offset > inst_count) {
      compare_count = 0;
    }
    cout << "No difference in " << compare_count << " instructions" << endl;
  }
  return true;
}

static void addExclusion(const string &_exclusions, unordered_set<int> &_list) {
  // Exclusions may be comma-separated
  string s;
  char c;
  for (uint64_t i = 0; i < _exclusions.size(); i++) {
    c = _exclusions[i];
    if ((c >= 65) && (c <= 90)) {
      c += 32;  // Make upper-case letters into lower-case
    }
    if ((c >= 97) && (c <= 122)) {
      s += c;  // A lower-case letter
    } else if ((c >= 48) && (c <= 57)) {
      s += c;  // A digit 0-9
    }
    if (s.size() == 2) {
      int index = indexForLabel(s);
      if (index == -1) {
        cout << "Invalid register name '" << s << "'" << endl;
      } else {
        _list.insert(index);
      }
      s.clear();
    }
  }
}

static void usage() {
  const char *msg =
    "\nUsage: regdiff [options] <file 1> <file 2>\n"
    "    -o   Offset instructions (i.e., starting point for comparison)\n"
    "    -x   Exclude registers in comparison, e.g., 'k1', 'K1', 'a0,s4,gp,hi,lo'\n"
    "    -h   Print this help message\n"
    "\n";
  cout << msg;
  exit(1);
}

int main(int argc, char *argv[]) {
  string input_1, input_2;
  uint64_t offset = 0;
  unordered_set<int> excludes;
  int ch;

  while ((ch = getopt(argc, argv, "ho:x:")) != -1) {
    switch (ch) {
      case 'h':
        usage();
        break;
      case 'o':
        offset = strtoul(optarg, nullptr, 0);
        break;
      case 'x':
        addExclusion(optarg, excludes);
        break;
      default:
        usage();
        break;
    }
  }
  argc -= optind;
  argv += optind;

  if (argc != 2) {
    usage();
  }
  input_1 = string(argv[0]);
  input_2 = string(argv[1]);

  ifstream file_1(input_1);
  if (!file_1) {
    cout << "Error opening '" << input_1 << "'" << endl;
    return 1;
  }
  ifstream file_2(input_2);
  if (!file_2) {
    cout << "Error opening '" << input_2 << "'" << endl;
  }
  if (!regdiff(file_1, file_2, offset, excludes)) {
    return 1;
  }

  return 0;
}
