# v2.3.3

Fixed a bug with alignment of multiline strings when the first line contains characters whose display width is not equal to the number of bytes.

# v2.3.2

Added compatibility with CommonMark@1.

# v2.3.1

Fixed a bug which caused `jlfmt --threads=N` to fail for `N > 1`.

Fixed a bug with alignment of `=` characters in lines with zero-width characters.
