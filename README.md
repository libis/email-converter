# email-converter
A command line tool to convert email messages into HTML or PDF

## Installation

There are executable application for most common OS types available. Download it from the list of assets in the latest release and copy (and optionally rename) it to a location that you can run it from (e.g. is in your PATH setting). You may have to set the executable bit on the downloaded file. Note that the `macos-14` version is meant for all Apple Silicon versions.

The executables are created with [OCRAN](https://github.com/Largo/ocran) and are self-extracting Ruby applications. The extraction causes a very short delay in the execution. If you want to use the application on large quantities of email files, you will get the best performance when you use the bulk conversion options (entire directories and recursive option) to minimize the impact of that startup delay.

You can also use the source code directly if you wish and run it with a ruby runtime once you cloned the repository. The Ruby version used to develop this code is Ruby v4.0.6. Probably any Ruby v4+ version will work. You will probably have to run `bundle install` first to install all the dependencies for the script. The main script is `bin/email_converter.rb` and should be executable and runnable in a linux/macos shell but it cal also be executed with `ruby bin/email_converter.rb`. If you want to integrate the code in your application, see the script on how the actual code is called.

By default each email will be converted into HTML. If you want to create PDF output for each email (the `-o pdf` option) then you will also need the wkhtmltopdf tool as the converter relies on that tool for the PDF output. The tool often is packaged as wkhtmltox. If you try to convert an email to PDF without the tool installed, you will get an error message about something missing. The wkhtmltopdf tool can be dpwnloaded from [here](https://wkhtmltopdf.org/downloads.html). Linux and MacOS version often have packages available as wkhtmltopdf or wkhtmltox. If the tool is installed so that it can be found from anywhere (i.o.w. listed in the PATH environment variable), there is nothing more to do on Linux and Mac. Otherwise, including on Windows, you will need to use the `--wkhtmltopdf_path` option to indicate where the tool is installed.

## Usage

Run the executable with the option `-h` to see the help text:

```sh
Usage: email_converter [options] <source> ...

if <source> is a directory, the recursive option can be used

The default pdf options are:
  page_size=A4
  orientation=Portrait
  margin_top=10mm
  margin_bottom=10mm
  margin_left=10mm
  margin_right=10mm
  dpi=300
  quiet=true

Options:
    -h, --help                       Display this help message
    -q, --quiet                      Suppress output messages
    -i, --input FORMAT               Specify the input format (eml or msg, default is derived from the file extension)
    -o, --output FORMAT              Specify the output format (pdf or html, default: html)
    -d, --outdir DIR                 Specify the output directory (default: current directory)
    -v, --version                    Display the version
    -r, --recursive                  Enable recursive processing of directories
        --no-recursive-convert       Disable recursive conversion of embedded/attached emails
        --export-converted           Enable exporting of converted attached emails
        --wkhtmltopdf_path PATH      Specify the path to the wkhtmltopdf executable
        --wkhtmltopdf_verbose        Enable verbose output for wkhtmltopdf
        --pdf_options OPTIONS        Specify additional options for wkhtmltopdf (in JSON format)
```

By default, the application will output the text: `Successfully converted '<source file>' to <HTLM or PDF>` for each file converted. Or it will output `Error converting '<source file>' to <HTML or PDF>` if something goes wrong along with the error message itself.

You can suppress this output with the `--quiet` option. In any case a `<source file>.json` JSON file will be created in the output directory that will contain any warning or error messages. Additionally the JSON file contains information extracted from the email header and a list of all attachment files that were saved on the disk.

You specify the location of the generated conversion as a directory with the `--output-dir` option. If the option is omitted, the current working directory will be used.

You can specify the source as a directory and all the files in the will be converted to the output directory. Adding the `--recursive` option will process all files in any subdirectory as well.

Attachments will be created in a folder next to the converted email with the name `<converted file>.attachments`.  Recursive embedded emails with attachments will create attachment subdirectories following the hierarchy of the embedded emails.

The tool will attempt to convert embedded or attached emails recursively. 'attempt' because some email applications have peculiar ways to attach emails which makes extracting all the email info hard to impossible. If an embedded/attached email is converted, it will be converted to the same output format and attachments will also be exported recursively. This feature can be disabled with the option `--no-recursive-convert`.

The option `--export-converted` on the other hand will attempt to export an attached mail as a file in the attachments directory. This will often not be possible, especially with Outlook msg files as Outlook integrates embedded msg files so tightly that it is not possible to recreate the original msg file. EML emails with attached EML files have the highest rates of success. Both options`--no-recursive-convert` and `--export-converted` can be combined.

**Note:** When using the bulk email option, you should make sure that the file names are unique as the tool will not check if a file in the output directory already exists. It will simply overwrite any existing file. Since the output file name follows the input file name, any duplicate file name (e.g. in different subdirectories) will overwrite the converted file of the other.

## Contributing

I had a solid bunch of email messages to test the tool against, but unfortunately they cannot be made public. If you have emails to contribute, please do so as I would like to implment some tests to the repository. You can add them to a `test` sub-directory or submit them in the Discussions as a `Email contribution`. Please describe the input (e.g. email client used, OS platform) and indicate what you would expect as conversion output (screenshots, attachment list).
