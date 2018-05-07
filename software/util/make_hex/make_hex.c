/*
 * File          : make_hex.c
 * Project       : MIPS32r1
 * Creator(s)    : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Modification History:
 *   Rev   Date         Initials  Description of Change
 *   1.0   4-1-2011     GEA       Initial design.
 *
 * Standards/Formatting:
 *   C99, 4 soft tab, 80 column
 *
 * Description:
 *   Converts binary data into a hexadecimal or COE file.
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <getopt.h>

void usage(void);

int main(int argc, char **argv)
{
    char *i_name, *o_name;
    int  word_size = 4;
    int  pad_length = 0;
    int  make_coe = 0;
    int  ch;

    while ((ch = getopt(argc, argv, "hcw:p:")) != -1)
    {
        switch (ch)
        {
            case 'h':
                usage();
                break;
            case 'c':
                make_coe = 1;
                break;
            case 'w':
                word_size = (int)strtol(optarg, (char **)NULL, 10);
                break;
            case 'p':
                pad_length = 1024 * (int)strtol(optarg, (char **)NULL, 10);
                if (pad_length < 0) {
                    pad_length = 0;
                }
                break;
            default:
                usage();
        }
    }

    argc -= optind;
    argv += optind;

    if (argc != 2)
    {
        usage();
    }

    i_name = argv[0];
    o_name = argv[1];

    /* Read the input file */
    FILE *file = fopen(i_name, "rb");
    if (file == NULL) {
        fprintf(stderr, "Error: Could not open \"%s\".\n", i_name);
        exit(1);
    }
    fseek(file, 0L, SEEK_END);
    int i_size = (int)ftell(file);
    if ((i_size < 0) || (ftell(file) > (long)i_size)) {
        fprintf(stderr, "Error: Input file is too large.\n");
        exit(1);
    }
    if (pad_length < i_size) {
        pad_length = i_size;
    }
    fseek(file, 0L, SEEK_SET);
    unsigned char *i_data = (unsigned char *)calloc(pad_length, 1);
    if (i_data == NULL) {
        fprintf(stderr, "Error: Could not allocate %d bytes of "
            "memory.\n", i_size);
        exit(1);
    }
    if (fread(i_data, 1, i_size, file) != (size_t)i_size) {
        fprintf(stderr, "Error reading input file.\n");
        exit(1);
    }
    fclose(file);

    /* Write the output file */
    file = fopen(o_name, "wb+");
    if (file == NULL) {
        fprintf(stderr, "Error: Could not open \"%s\" for "
            "writing.\n", o_name);
        exit(1);
    }
    if (make_coe) {
        fprintf(file, "memory_initialization_radix=16;\n"
            "memory_initialization_vector=\n");
    }
    int bytes_remaining = pad_length;
    int full_lines = pad_length / word_size;
    for (int i = 0; i < full_lines; i++) {
        for (int j = 0; j < word_size; j++) {
            fprintf(file, "%02x", i_data[(i*word_size)+j]);
        }
        bytes_remaining -= word_size;
        if (bytes_remaining > 0) {
            if (make_coe) {
                fprintf(file, ",\n");
            }
            else {
                fprintf(file, "\n");
            }
        }
    }
    while (bytes_remaining > 0) {
        fprintf(file, "%02x", i_data[i_size - bytes_remaining]);
        bytes_remaining -= 1;
    }
    if (make_coe) {
        fprintf(file, ";");
    }
    fclose(file);

    return 0;
}

void usage(void)
{
    const char *msg =
    "\nUsage: make_hex [options] <input file> <output file>\n"
    "Options:\n"
    "   -c             Make a COE file\n"
    "   -p <pad size>  Zero-pad to a minimum total output size (KB)\n"
    "   -w <word size> Number of input bytes per line\n"
    "\n";
    fprintf(stderr, "%s", msg);
    exit(1);
}

