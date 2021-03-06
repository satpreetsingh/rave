% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils_general.R
\name{try_normalizePath}
\alias{try_normalizePath}
\title{Try to find absolute path without error}
\usage{
try_normalizePath(path, sep = c('/', '\\\\'))
}
\description{
Try to find absolute path without error
}
\details{
It's always good to use "/" to separate path. I haven't tested
on windows, but this function should work. Basically this function uses
base::normalizePath. However base::normalizePath returns error if file
does not exist. try_normalizePath will check parent directories and try to
find absolute path for parent directories.
}
\examples{
\dontrun{
# "./" exist
try_normalizePath('./')

# Case when path not exist
try_normalizePath("./this/path/does/not/exist/")
}
}
