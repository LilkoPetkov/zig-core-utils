# cat.zig

A simple implementation of the `cat` command-line utility written in Zig.

## Features

*   Read and display file contents.
*   Show line numbers.
*   Show `$` at the end of lines.
*   Number nonempty output lines.

## Usage

1.  **Build the project:**

    ```bash
    zig build --release=fast
    ```

2.  **Run the utility:**

    ```bash
    ./zig-out/bin/cat_zig -f <file_path> [options]
    ```

    **Available Options:**

    *   `-f`, `--file_path`: Path to the file to be displayed.
    *   `-n`, `--num_line`: Show line numbers.
    *   `-e`, `--show_ends`: Show `$` at the end of lines.
    *   `-b`, `--number_nonblank`: Number nonempty output lines.

## Example

To display the contents of a file named `arsene_lupin.txt` with line numbers:

```bash
./zig-out/bin/cat_zig -f arsene_lupin.txt -n
```

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue.

## License

This project is licensed under the MIT License.
