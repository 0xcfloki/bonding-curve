#!/usr/bin/env python3
import argparse
import csv
import os
import sys
from decimal import Decimal, getcontext

# Set Decimal precision to 40 digits
getcontext().prec = 40


def main():
    parser = argparse.ArgumentParser(
        description="Compute x**(exp_num/exp_den) for the first column of a CSV and append the result."
    )
    parser.add_argument("input_path", help="Path to the input CSV file")
    parser.add_argument("exp_num", help="Exponent numerator")
    parser.add_argument("exp_den", help="Exponent denominator")
    args = parser.parse_args()

    if not os.path.isfile(args.input_path):
        print(f"Error: file not found: {args.input_path}", file=sys.stderr)
        sys.exit(1)

    exp_num_dec = Decimal(args.exp_num)
    exp_den_dec = Decimal(args.exp_den)
    if exp_den_dec == 0:
        print("Error: exp_den cannot be zero.", file=sys.stderr)
        sys.exit(1)

    # Build output path: insert "_errors" before the extension
    base, ext = os.path.splitext(args.input_path)
    output_path = f"{base}_errors{ext}"

    try:
        with open(args.input_path, newline='', encoding='utf-8') as infile, \
             open(output_path, 'w', newline='', encoding='utf-8') as outfile:
            reader = csv.reader(infile)
            writer = csv.writer(outfile)

            writer.writerow(["Input", "ABDK", "PRB", "Python", "ABDK abs err", "ABDK rel err", "PRB abs err", "PRB rel err"])
            for row in reader:
                if not row:
                    # Preserve empty lines as-is
                    writer.writerow(row)
                    continue

                x = Decimal(row[0].strip())
                exponent = exp_num_dec / exp_den_dec
                result = x ** exponent

                # ABDK errors
                a = Decimal(row[1].strip())
                a_abs_err = abs(result - a)
                a_rel_err = a_abs_err / result

                # PRB errors
                p = Decimal(row[2].strip())
                p_abs_err = abs(result - p)
                p_rel_err = p_abs_err / result

                # Append the computed values as a new columns
                new_row = row + [str(result), str(a_abs_err), str(a_rel_err), str(p_abs_err), str(p_rel_err)]
                writer.writerow(new_row)

    except Exception as e:
        print(f"Error processing file: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Done. Output saved to: {output_path}")


if __name__ == "__main__":
    main()
